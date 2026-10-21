import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:carina/core/core.dart';
import 'package:carina/features/playlists/data/lan_address.dart';
import 'package:carina/features/playlists/data/phone_setup_page.dart';
import 'package:carina/features/playlists/data/phone_setup_server.dart';
import 'package:carina/features/playlists/data/wizard_form.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

/// Starts the one-shot phone server on the LAN address, or returns null when
/// the device has none. Overridden in widget tests (a real socket does not
/// bind inside their fake-async zone).
typedef PhoneSetupStarter = Future<PhoneSetupHandle?> Function({
  required String page,
  required void Function(WizardValues values) onSubmitted,
  required void Function() onExpired,
});

final phoneSetupStarterProvider = Provider<PhoneSetupStarter>(
  (ref) => ({required page, required onSubmitted, required onExpired}) async {
    final address = await findLanAddress();
    if (address == null) return null;
    return PhoneSetupServer.start(
      address: address,
      page: page,
      onSubmitted: onSubmitted,
      onExpired: onExpired,
    );
  },
);

enum _Phase { starting, waiting, noNetwork, failed, expired }

/// "Use your phone": a QR code and the plain address of a page on this
/// device where the playlist can be typed on a phone. The server lives
/// exactly as long as this panel is mounted. [onReceived] gets the checked
/// values of the one accepted submission.
class PhoneSetupPanel extends ConsumerStatefulWidget {
  const PhoneSetupPanel({
    super.key,
    required this.onReceived,
    required this.onCancel,
  });

  final ValueChanged<WizardValues> onReceived;
  final VoidCallback onCancel;

  @override
  ConsumerState<PhoneSetupPanel> createState() => _PhoneSetupPanelState();
}

class _PhoneSetupPanelState extends ConsumerState<PhoneSetupPanel> {
  PhoneSetupHandle? _handle;
  _Phase _phase = _Phase.starting;
  Uri? _url;
  bool _started = false;
  int _generation = 0;

  /// The QR code is a white tile with dark modules: inverted codes fail on
  /// many phone cameras.
  static const double _qrSize = 256;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_start());
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_handle?.close());
    super.dispose();
  }

  Future<void> _start() async {
    final generation = ++_generation;
    final l10n = L10n.of(context);
    final page = buildPhoneSetupPage(
      lang: l10n.localeName,
      strings: phoneSetupStrings(l10n),
    );
    final starter = ref.read(phoneSetupStarterProvider);
    PhoneSetupHandle? handle;
    try {
      handle = await starter(
        page: page,
        onSubmitted: (values) {
          if (mounted && generation == _generation) widget.onReceived(values);
        },
        onExpired: () {
          if (mounted && generation == _generation) {
            setState(() => _phase = _Phase.expired);
          }
        },
      );
    } on Object catch (error) {
      debugPrint('Starting the phone server failed: ${error.runtimeType}');
      if (mounted && generation == _generation) {
        setState(() => _phase = _Phase.failed);
      }
      return;
    }
    if (!mounted || generation != _generation) {
      unawaited(handle?.close());
      return;
    }
    setState(() {
      _handle = handle;
      _url = handle?.url;
      _phase = handle == null ? _Phase.noNetwork : _Phase.waiting;
    });
  }

  void _retry() {
    unawaited(_handle?.close());
    setState(() {
      _handle = null;
      _url = null;
      _phase = _Phase.starting;
    });
    unawaited(_start());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final retryable = switch (_phase) {
      _Phase.noNetwork || _Phase.failed || _Phase.expired => true,
      _ => false,
    };
    final status = switch (_phase) {
      _Phase.starting => l10n.playlistsPhoneStarting,
      _Phase.waiting => l10n.playlistsPhoneWaiting,
      _Phase.noNetwork => l10n.playlistsPhoneNoNetwork,
      _Phase.failed => l10n.playlistsPhoneFailed,
      _Phase.expired => l10n.playlistsPhoneExpired,
    };
    final url = _url;
    final live = _phase == _Phase.waiting && url != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _QrTile(
            size: _qrSize,
            data: live ? url.toString() : null,
            semanticLabel: l10n.playlistsPhoneQrLabel,
          ),
        ),
        const SizedBox(width: 56),
        Expanded(
          child: FocusTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.playlistsPhoneTitle,
                    style: _PhoneStyles.title,
                  ),
                ),
                const SizedBox(height: 16),
                _Step(1, l10n.playlistsPhoneStep1),
                const SizedBox(height: 8),
                _Step(2, l10n.playlistsPhoneStep2),
                const SizedBox(height: 8),
                _Step(3, l10n.playlistsPhoneStep3),
                const SizedBox(height: 18),
                if (live)
                  Container(
                    key: const ValueKey('phone-setup-url'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: KColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(url.toString(), style: _PhoneStyles.url),
                  ),
                const SizedBox(height: 12),
                Row(
                  key: const ValueKey('phone-setup-status'),
                  children: [
                    if (_phase == _Phase.waiting ||
                        _phase == _Phase.starting) ...[
                      const KSpinner(size: 16, strokeWidth: 2),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        status,
                        style: KText.bodySecondary.copyWith(
                          color: retryable
                              ? KColors.textPrimary
                              : KColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (retryable) ...[
                      KButton.accent(
                        key: const ValueKey('phone-setup-retry'),
                        label: l10n.playlistsPhoneRetry,
                        autofocus: true,
                        onPressed: _retry,
                      ),
                      const SizedBox(width: 12),
                    ],
                    KButton.secondary(
                      key: const ValueKey('phone-setup-cancel'),
                      label: l10n.cancel,
                      autofocus: !retryable,
                      onPressed: widget.onCancel,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Text styles of the panel (the wizard's 32 px headline, a tabular URL).
abstract final class _PhoneStyles {
  static const TextStyle title = TextStyle(
    fontFamily: KText.family,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.9,
    height: 1.18,
    color: KColors.textPrimary,
  );

  static const TextStyle url = TextStyle(
    fontFamily: KText.family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: KColors.textPrimary,
    fontFeatures: KText.tabular,
  );
}

/// One numbered line of the instructions.
class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            color: KColors.surface3,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: KText.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: KColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: KText.bodySecondary.copyWith(
              fontSize: 16,
              color: const Color(0xFFC4C4C6),
            ),
          ),
        ),
      ],
    );
  }
}

/// The QR code on a white tile; an empty dark tile while there is nothing
/// to scan.
class _QrTile extends StatelessWidget {
  const _QrTile({required this.size, this.data, required this.semanticLabel});

  final double size;
  final String? data;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    const padding = 14.0;
    final data = this.data;
    return Container(
      key: const ValueKey('phone-setup-qr'),
      width: size + padding * 2,
      height: size + padding * 2,
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: data == null ? KColors.surface2 : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: data == null
          ? null
          : Semantics(
              label: semanticLabel,
              image: true,
              child: QrImageView(
                data: data,
                size: size,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
    );
  }
}
