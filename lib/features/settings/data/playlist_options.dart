import '../../../data/repositories/playlist_repository.dart';

/// Edits of the playlist fields that Settings → Playlist Management shows
/// (reload frequency, EPG time shift) through the repository's own update,
/// so the source, the stored EPG URL and the password stay as they are.
extension PlaylistOptionsX on PlaylistRepository {
  /// Saves [reloadFrequencyHours] and / or [epgShiftHours] of playlist
  /// [id]. Returns what changed (`epg` is true when the shift changed and
  /// the guide must be reloaded), or null when the playlist is gone.
  /// Throws [ArgumentError] when the stored source is incomplete (e.g. an
  /// Xtream password lost from the secure store).
  Future<PlaylistChanges?> updateOptions(
    int id, {
    int? reloadFrequencyHours,
    int? epgShiftHours,
  }) async {
    final row = await get(id);
    if (row == null) return null;
    final draft = PlaylistDraft(
      name: row.name,
      type: row.type,
      server: row.server,
      username: row.username,
      // null keeps the stored password.
      password: null,
      m3uUrl: row.m3uUrl,
      // The stored value as is: null = default, '' = off, else custom.
      epgUrl: row.epgUrl,
      epgShiftHours: epgShiftHours ?? row.epgShiftHours,
      reloadFrequencyHours: reloadFrequencyHours ?? row.reloadFrequencyHours,
      userAgent: row.userAgent,
      avatarId: row.avatarId,
    );
    return updateWithChanges(id, draft);
  }
}
