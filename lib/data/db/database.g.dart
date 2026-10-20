// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class SearchIndex extends Table
    with
        TableInfo<SearchIndex, SearchIndexData>,
        VirtualTableInfo<SearchIndex, SearchIndexData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SearchIndex(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _normalizedMeta = const VerificationMeta(
    'normalized',
  );
  late final GeneratedColumn<String> normalized = GeneratedColumn<String>(
    'normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  late final GeneratedColumn<String> refId = GeneratedColumn<String>(
    'ref_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    normalized,
    title,
    kind,
    refId,
    playlistId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_index';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchIndexData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('normalized')) {
      context.handle(
        _normalizedMeta,
        normalized.isAcceptableOrUnknown(data['normalized']!, _normalizedMeta),
      );
    } else if (isInserting) {
      context.missing(_normalizedMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('ref_id')) {
      context.handle(
        _refIdMeta,
        refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta),
      );
    } else if (isInserting) {
      context.missing(_refIdMeta);
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  SearchIndexData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchIndexData(
      normalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      refId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
    );
  }

  @override
  SearchIndex createAlias(String alias) {
    return SearchIndex(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(normalized, title UNINDEXED, kind UNINDEXED, ref_id UNINDEXED, playlist_id UNINDEXED, tokenize = \'unicode61 remove_diacritics 2\', prefix = \'2 3\')';
}

class SearchIndexData extends DataClass implements Insertable<SearchIndexData> {
  final String normalized;
  final String title;
  final String kind;
  final String refId;
  final String playlistId;
  const SearchIndexData({
    required this.normalized,
    required this.title,
    required this.kind,
    required this.refId,
    required this.playlistId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['normalized'] = Variable<String>(normalized);
    map['title'] = Variable<String>(title);
    map['kind'] = Variable<String>(kind);
    map['ref_id'] = Variable<String>(refId);
    map['playlist_id'] = Variable<String>(playlistId);
    return map;
  }

  SearchIndexCompanion toCompanion(bool nullToAbsent) {
    return SearchIndexCompanion(
      normalized: Value(normalized),
      title: Value(title),
      kind: Value(kind),
      refId: Value(refId),
      playlistId: Value(playlistId),
    );
  }

  factory SearchIndexData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchIndexData(
      normalized: serializer.fromJson<String>(json['normalized']),
      title: serializer.fromJson<String>(json['title']),
      kind: serializer.fromJson<String>(json['kind']),
      refId: serializer.fromJson<String>(json['ref_id']),
      playlistId: serializer.fromJson<String>(json['playlist_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'normalized': serializer.toJson<String>(normalized),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<String>(kind),
      'ref_id': serializer.toJson<String>(refId),
      'playlist_id': serializer.toJson<String>(playlistId),
    };
  }

  SearchIndexData copyWith({
    String? normalized,
    String? title,
    String? kind,
    String? refId,
    String? playlistId,
  }) => SearchIndexData(
    normalized: normalized ?? this.normalized,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    refId: refId ?? this.refId,
    playlistId: playlistId ?? this.playlistId,
  );
  SearchIndexData copyWithCompanion(SearchIndexCompanion data) {
    return SearchIndexData(
      normalized: data.normalized.present
          ? data.normalized.value
          : this.normalized,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      refId: data.refId.present ? data.refId.value : this.refId,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchIndexData(')
          ..write('normalized: $normalized, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('refId: $refId, ')
          ..write('playlistId: $playlistId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(normalized, title, kind, refId, playlistId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchIndexData &&
          other.normalized == this.normalized &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.refId == this.refId &&
          other.playlistId == this.playlistId);
}

class SearchIndexCompanion extends UpdateCompanion<SearchIndexData> {
  final Value<String> normalized;
  final Value<String> title;
  final Value<String> kind;
  final Value<String> refId;
  final Value<String> playlistId;
  final Value<int> rowid;
  const SearchIndexCompanion({
    this.normalized = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.refId = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchIndexCompanion.insert({
    required String normalized,
    required String title,
    required String kind,
    required String refId,
    required String playlistId,
    this.rowid = const Value.absent(),
  }) : normalized = Value(normalized),
       title = Value(title),
       kind = Value(kind),
       refId = Value(refId),
       playlistId = Value(playlistId);
  static Insertable<SearchIndexData> custom({
    Expression<String>? normalized,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<String>? refId,
    Expression<String>? playlistId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (normalized != null) 'normalized': normalized,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (refId != null) 'ref_id': refId,
      if (playlistId != null) 'playlist_id': playlistId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchIndexCompanion copyWith({
    Value<String>? normalized,
    Value<String>? title,
    Value<String>? kind,
    Value<String>? refId,
    Value<String>? playlistId,
    Value<int>? rowid,
  }) {
    return SearchIndexCompanion(
      normalized: normalized ?? this.normalized,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      refId: refId ?? this.refId,
      playlistId: playlistId ?? this.playlistId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (normalized.present) {
      map['normalized'] = Variable<String>(normalized.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (refId.present) {
      map['ref_id'] = Variable<String>(refId.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchIndexCompanion(')
          ..write('normalized: $normalized, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('refId: $refId, ')
          ..write('playlistId: $playlistId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ProgrammeSearch extends Table
    with
        TableInfo<ProgrammeSearch, ProgrammeSearchData>,
        VirtualTableInfo<ProgrammeSearch, ProgrammeSearchData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ProgrammeSearch(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _normalizedMeta = const VerificationMeta(
    'normalized',
  );
  late final GeneratedColumn<String> normalized = GeneratedColumn<String>(
    'normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _programmeIdMeta = const VerificationMeta(
    'programmeId',
  );
  late final GeneratedColumn<String> programmeId = GeneratedColumn<String>(
    'programme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [normalized, programmeId, playlistId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'programme_search';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgrammeSearchData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('normalized')) {
      context.handle(
        _normalizedMeta,
        normalized.isAcceptableOrUnknown(data['normalized']!, _normalizedMeta),
      );
    } else if (isInserting) {
      context.missing(_normalizedMeta);
    }
    if (data.containsKey('programme_id')) {
      context.handle(
        _programmeIdMeta,
        programmeId.isAcceptableOrUnknown(
          data['programme_id']!,
          _programmeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programmeIdMeta);
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  ProgrammeSearchData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgrammeSearchData(
      normalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized'],
      )!,
      programmeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}programme_id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
    );
  }

  @override
  ProgrammeSearch createAlias(String alias) {
    return ProgrammeSearch(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(normalized, programme_id UNINDEXED, playlist_id UNINDEXED, tokenize = \'unicode61 remove_diacritics 2\', prefix = \'2 3\')';
}

class ProgrammeSearchData extends DataClass
    implements Insertable<ProgrammeSearchData> {
  final String normalized;
  final String programmeId;
  final String playlistId;
  const ProgrammeSearchData({
    required this.normalized,
    required this.programmeId,
    required this.playlistId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['normalized'] = Variable<String>(normalized);
    map['programme_id'] = Variable<String>(programmeId);
    map['playlist_id'] = Variable<String>(playlistId);
    return map;
  }

  ProgrammeSearchCompanion toCompanion(bool nullToAbsent) {
    return ProgrammeSearchCompanion(
      normalized: Value(normalized),
      programmeId: Value(programmeId),
      playlistId: Value(playlistId),
    );
  }

  factory ProgrammeSearchData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgrammeSearchData(
      normalized: serializer.fromJson<String>(json['normalized']),
      programmeId: serializer.fromJson<String>(json['programme_id']),
      playlistId: serializer.fromJson<String>(json['playlist_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'normalized': serializer.toJson<String>(normalized),
      'programme_id': serializer.toJson<String>(programmeId),
      'playlist_id': serializer.toJson<String>(playlistId),
    };
  }

  ProgrammeSearchData copyWith({
    String? normalized,
    String? programmeId,
    String? playlistId,
  }) => ProgrammeSearchData(
    normalized: normalized ?? this.normalized,
    programmeId: programmeId ?? this.programmeId,
    playlistId: playlistId ?? this.playlistId,
  );
  ProgrammeSearchData copyWithCompanion(ProgrammeSearchCompanion data) {
    return ProgrammeSearchData(
      normalized: data.normalized.present
          ? data.normalized.value
          : this.normalized,
      programmeId: data.programmeId.present
          ? data.programmeId.value
          : this.programmeId,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgrammeSearchData(')
          ..write('normalized: $normalized, ')
          ..write('programmeId: $programmeId, ')
          ..write('playlistId: $playlistId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(normalized, programmeId, playlistId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgrammeSearchData &&
          other.normalized == this.normalized &&
          other.programmeId == this.programmeId &&
          other.playlistId == this.playlistId);
}

class ProgrammeSearchCompanion extends UpdateCompanion<ProgrammeSearchData> {
  final Value<String> normalized;
  final Value<String> programmeId;
  final Value<String> playlistId;
  final Value<int> rowid;
  const ProgrammeSearchCompanion({
    this.normalized = const Value.absent(),
    this.programmeId = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgrammeSearchCompanion.insert({
    required String normalized,
    required String programmeId,
    required String playlistId,
    this.rowid = const Value.absent(),
  }) : normalized = Value(normalized),
       programmeId = Value(programmeId),
       playlistId = Value(playlistId);
  static Insertable<ProgrammeSearchData> custom({
    Expression<String>? normalized,
    Expression<String>? programmeId,
    Expression<String>? playlistId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (normalized != null) 'normalized': normalized,
      if (programmeId != null) 'programme_id': programmeId,
      if (playlistId != null) 'playlist_id': playlistId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgrammeSearchCompanion copyWith({
    Value<String>? normalized,
    Value<String>? programmeId,
    Value<String>? playlistId,
    Value<int>? rowid,
  }) {
    return ProgrammeSearchCompanion(
      normalized: normalized ?? this.normalized,
      programmeId: programmeId ?? this.programmeId,
      playlistId: playlistId ?? this.playlistId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (normalized.present) {
      map['normalized'] = Variable<String>(normalized.value);
    }
    if (programmeId.present) {
      map['programme_id'] = Variable<String>(programmeId.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgrammeSearchCompanion(')
          ..write('normalized: $normalized, ')
          ..write('programmeId: $programmeId, ')
          ..write('playlistId: $playlistId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PlaylistType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<PlaylistType>($PlaylistsTable.$convertertype);
  static const VerificationMeta _serverMeta = const VerificationMeta('server');
  @override
  late final GeneratedColumn<String> server = GeneratedColumn<String>(
    'server',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _m3uUrlMeta = const VerificationMeta('m3uUrl');
  @override
  late final GeneratedColumn<String> m3uUrl = GeneratedColumn<String>(
    'm3u_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epgUrlMeta = const VerificationMeta('epgUrl');
  @override
  late final GeneratedColumn<String> epgUrl = GeneratedColumn<String>(
    'epg_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epgShiftHoursMeta = const VerificationMeta(
    'epgShiftHours',
  );
  @override
  late final GeneratedColumn<int> epgShiftHours = GeneratedColumn<int>(
    'epg_shift_hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reloadFrequencyHoursMeta =
      const VerificationMeta('reloadFrequencyHours');
  @override
  late final GeneratedColumn<int> reloadFrequencyHours = GeneratedColumn<int>(
    'reload_frequency_hours',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(72),
  );
  static const VerificationMeta _userAgentMeta = const VerificationMeta(
    'userAgent',
  );
  @override
  late final GeneratedColumn<String> userAgent = GeneratedColumn<String>(
    'user_agent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarIdMeta = const VerificationMeta(
    'avatarId',
  );
  @override
  late final GeneratedColumn<String> avatarId = GeneratedColumn<String>(
    'avatar_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasAccessPinMeta = const VerificationMeta(
    'hasAccessPin',
  );
  @override
  late final GeneratedColumn<bool> hasAccessPin = GeneratedColumn<bool>(
    'has_access_pin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_access_pin" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReloadAtMeta = const VerificationMeta(
    'lastReloadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReloadAt = GeneratedColumn<DateTime>(
    'last_reload_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastEpgReloadAtMeta = const VerificationMeta(
    'lastEpgReloadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastEpgReloadAt =
      GeneratedColumn<DateTime>(
        'last_epg_reload_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _accountJsonMeta = const VerificationMeta(
    'accountJson',
  );
  @override
  late final GeneratedColumn<String> accountJson = GeneratedColumn<String>(
    'account_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _m3uHeaderJsonMeta = const VerificationMeta(
    'm3uHeaderJson',
  );
  @override
  late final GeneratedColumn<String> m3uHeaderJson = GeneratedColumn<String>(
    'm3u_header_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _liveCountMeta = const VerificationMeta(
    'liveCount',
  );
  @override
  late final GeneratedColumn<int> liveCount = GeneratedColumn<int>(
    'live_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _movieCountMeta = const VerificationMeta(
    'movieCount',
  );
  @override
  late final GeneratedColumn<int> movieCount = GeneratedColumn<int>(
    'movie_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seriesCountMeta = const VerificationMeta(
    'seriesCount',
  );
  @override
  late final GeneratedColumn<int> seriesCount = GeneratedColumn<int>(
    'series_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _programmeCountMeta = const VerificationMeta(
    'programmeCount',
  );
  @override
  late final GeneratedColumn<int> programmeCount = GeneratedColumn<int>(
    'programme_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    server,
    username,
    m3uUrl,
    epgUrl,
    epgShiftHours,
    reloadFrequencyHours,
    userAgent,
    avatarId,
    hasAccessPin,
    sortIndex,
    createdAt,
    lastReloadAt,
    lastEpgReloadAt,
    accountJson,
    m3uHeaderJson,
    liveCount,
    movieCount,
    seriesCount,
    programmeCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('server')) {
      context.handle(
        _serverMeta,
        server.isAcceptableOrUnknown(data['server']!, _serverMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('m3u_url')) {
      context.handle(
        _m3uUrlMeta,
        m3uUrl.isAcceptableOrUnknown(data['m3u_url']!, _m3uUrlMeta),
      );
    }
    if (data.containsKey('epg_url')) {
      context.handle(
        _epgUrlMeta,
        epgUrl.isAcceptableOrUnknown(data['epg_url']!, _epgUrlMeta),
      );
    }
    if (data.containsKey('epg_shift_hours')) {
      context.handle(
        _epgShiftHoursMeta,
        epgShiftHours.isAcceptableOrUnknown(
          data['epg_shift_hours']!,
          _epgShiftHoursMeta,
        ),
      );
    }
    if (data.containsKey('reload_frequency_hours')) {
      context.handle(
        _reloadFrequencyHoursMeta,
        reloadFrequencyHours.isAcceptableOrUnknown(
          data['reload_frequency_hours']!,
          _reloadFrequencyHoursMeta,
        ),
      );
    }
    if (data.containsKey('user_agent')) {
      context.handle(
        _userAgentMeta,
        userAgent.isAcceptableOrUnknown(data['user_agent']!, _userAgentMeta),
      );
    }
    if (data.containsKey('avatar_id')) {
      context.handle(
        _avatarIdMeta,
        avatarId.isAcceptableOrUnknown(data['avatar_id']!, _avatarIdMeta),
      );
    }
    if (data.containsKey('has_access_pin')) {
      context.handle(
        _hasAccessPinMeta,
        hasAccessPin.isAcceptableOrUnknown(
          data['has_access_pin']!,
          _hasAccessPinMeta,
        ),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_reload_at')) {
      context.handle(
        _lastReloadAtMeta,
        lastReloadAt.isAcceptableOrUnknown(
          data['last_reload_at']!,
          _lastReloadAtMeta,
        ),
      );
    }
    if (data.containsKey('last_epg_reload_at')) {
      context.handle(
        _lastEpgReloadAtMeta,
        lastEpgReloadAt.isAcceptableOrUnknown(
          data['last_epg_reload_at']!,
          _lastEpgReloadAtMeta,
        ),
      );
    }
    if (data.containsKey('account_json')) {
      context.handle(
        _accountJsonMeta,
        accountJson.isAcceptableOrUnknown(
          data['account_json']!,
          _accountJsonMeta,
        ),
      );
    }
    if (data.containsKey('m3u_header_json')) {
      context.handle(
        _m3uHeaderJsonMeta,
        m3uHeaderJson.isAcceptableOrUnknown(
          data['m3u_header_json']!,
          _m3uHeaderJsonMeta,
        ),
      );
    }
    if (data.containsKey('live_count')) {
      context.handle(
        _liveCountMeta,
        liveCount.isAcceptableOrUnknown(data['live_count']!, _liveCountMeta),
      );
    }
    if (data.containsKey('movie_count')) {
      context.handle(
        _movieCountMeta,
        movieCount.isAcceptableOrUnknown(data['movie_count']!, _movieCountMeta),
      );
    }
    if (data.containsKey('series_count')) {
      context.handle(
        _seriesCountMeta,
        seriesCount.isAcceptableOrUnknown(
          data['series_count']!,
          _seriesCountMeta,
        ),
      );
    }
    if (data.containsKey('programme_count')) {
      context.handle(
        _programmeCountMeta,
        programmeCount.isAcceptableOrUnknown(
          data['programme_count']!,
          _programmeCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: $PlaylistsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      server: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server'],
      ),
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      m3uUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}m3u_url'],
      ),
      epgUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_url'],
      ),
      epgShiftHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}epg_shift_hours'],
      )!,
      reloadFrequencyHours: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reload_frequency_hours'],
      )!,
      userAgent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_agent'],
      ),
      avatarId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_id'],
      ),
      hasAccessPin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_access_pin'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastReloadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reload_at'],
      ),
      lastEpgReloadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_epg_reload_at'],
      ),
      accountJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_json'],
      ),
      m3uHeaderJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}m3u_header_json'],
      ),
      liveCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}live_count'],
      )!,
      movieCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}movie_count'],
      )!,
      seriesCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_count'],
      )!,
      programmeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}programme_count'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PlaylistType, int, int> $convertertype =
      const EnumIndexConverter<PlaylistType>(PlaylistType.values);
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final int id;
  final String name;
  final PlaylistType type;

  /// Xtream: `https://host:port` exactly as entered (no trailing slash).
  final String? server;
  final String? username;

  /// M3U: playlist URL, or the absolute file path for [PlaylistType.m3uFile].
  final String? m3uUrl;
  final String? epgUrl;
  final int epgShiftHours;

  /// 0 = never. Defaults to 3 days.
  final int reloadFrequencyHours;
  final String? userAgent;

  /// Avatar id from the generated avatar catalog (see core/avatars).
  final String? avatarId;
  final bool hasAccessPin;
  final int sortIndex;
  final DateTime createdAt;
  final DateTime? lastReloadAt;
  final DateTime? lastEpgReloadAt;

  /// Raw Xtream `user_info` + `server_info` JSON from the last auth call.
  final String? accountJson;

  /// Header defaults from `#EXTM3U` (url-tvg, catchup…) as JSON.
  final String? m3uHeaderJson;
  final int liveCount;
  final int movieCount;
  final int seriesCount;
  final int programmeCount;
  const PlaylistRow({
    required this.id,
    required this.name,
    required this.type,
    this.server,
    this.username,
    this.m3uUrl,
    this.epgUrl,
    required this.epgShiftHours,
    required this.reloadFrequencyHours,
    this.userAgent,
    this.avatarId,
    required this.hasAccessPin,
    required this.sortIndex,
    required this.createdAt,
    this.lastReloadAt,
    this.lastEpgReloadAt,
    this.accountJson,
    this.m3uHeaderJson,
    required this.liveCount,
    required this.movieCount,
    required this.seriesCount,
    required this.programmeCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<int>($PlaylistsTable.$convertertype.toSql(type));
    }
    if (!nullToAbsent || server != null) {
      map['server'] = Variable<String>(server);
    }
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || m3uUrl != null) {
      map['m3u_url'] = Variable<String>(m3uUrl);
    }
    if (!nullToAbsent || epgUrl != null) {
      map['epg_url'] = Variable<String>(epgUrl);
    }
    map['epg_shift_hours'] = Variable<int>(epgShiftHours);
    map['reload_frequency_hours'] = Variable<int>(reloadFrequencyHours);
    if (!nullToAbsent || userAgent != null) {
      map['user_agent'] = Variable<String>(userAgent);
    }
    if (!nullToAbsent || avatarId != null) {
      map['avatar_id'] = Variable<String>(avatarId);
    }
    map['has_access_pin'] = Variable<bool>(hasAccessPin);
    map['sort_index'] = Variable<int>(sortIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastReloadAt != null) {
      map['last_reload_at'] = Variable<DateTime>(lastReloadAt);
    }
    if (!nullToAbsent || lastEpgReloadAt != null) {
      map['last_epg_reload_at'] = Variable<DateTime>(lastEpgReloadAt);
    }
    if (!nullToAbsent || accountJson != null) {
      map['account_json'] = Variable<String>(accountJson);
    }
    if (!nullToAbsent || m3uHeaderJson != null) {
      map['m3u_header_json'] = Variable<String>(m3uHeaderJson);
    }
    map['live_count'] = Variable<int>(liveCount);
    map['movie_count'] = Variable<int>(movieCount);
    map['series_count'] = Variable<int>(seriesCount);
    map['programme_count'] = Variable<int>(programmeCount);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      server: server == null && nullToAbsent
          ? const Value.absent()
          : Value(server),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      m3uUrl: m3uUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(m3uUrl),
      epgUrl: epgUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(epgUrl),
      epgShiftHours: Value(epgShiftHours),
      reloadFrequencyHours: Value(reloadFrequencyHours),
      userAgent: userAgent == null && nullToAbsent
          ? const Value.absent()
          : Value(userAgent),
      avatarId: avatarId == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarId),
      hasAccessPin: Value(hasAccessPin),
      sortIndex: Value(sortIndex),
      createdAt: Value(createdAt),
      lastReloadAt: lastReloadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReloadAt),
      lastEpgReloadAt: lastEpgReloadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEpgReloadAt),
      accountJson: accountJson == null && nullToAbsent
          ? const Value.absent()
          : Value(accountJson),
      m3uHeaderJson: m3uHeaderJson == null && nullToAbsent
          ? const Value.absent()
          : Value(m3uHeaderJson),
      liveCount: Value(liveCount),
      movieCount: Value(movieCount),
      seriesCount: Value(seriesCount),
      programmeCount: Value(programmeCount),
    );
  }

  factory PlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: $PlaylistsTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      server: serializer.fromJson<String?>(json['server']),
      username: serializer.fromJson<String?>(json['username']),
      m3uUrl: serializer.fromJson<String?>(json['m3uUrl']),
      epgUrl: serializer.fromJson<String?>(json['epgUrl']),
      epgShiftHours: serializer.fromJson<int>(json['epgShiftHours']),
      reloadFrequencyHours: serializer.fromJson<int>(
        json['reloadFrequencyHours'],
      ),
      userAgent: serializer.fromJson<String?>(json['userAgent']),
      avatarId: serializer.fromJson<String?>(json['avatarId']),
      hasAccessPin: serializer.fromJson<bool>(json['hasAccessPin']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastReloadAt: serializer.fromJson<DateTime?>(json['lastReloadAt']),
      lastEpgReloadAt: serializer.fromJson<DateTime?>(json['lastEpgReloadAt']),
      accountJson: serializer.fromJson<String?>(json['accountJson']),
      m3uHeaderJson: serializer.fromJson<String?>(json['m3uHeaderJson']),
      liveCount: serializer.fromJson<int>(json['liveCount']),
      movieCount: serializer.fromJson<int>(json['movieCount']),
      seriesCount: serializer.fromJson<int>(json['seriesCount']),
      programmeCount: serializer.fromJson<int>(json['programmeCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<int>(
        $PlaylistsTable.$convertertype.toJson(type),
      ),
      'server': serializer.toJson<String?>(server),
      'username': serializer.toJson<String?>(username),
      'm3uUrl': serializer.toJson<String?>(m3uUrl),
      'epgUrl': serializer.toJson<String?>(epgUrl),
      'epgShiftHours': serializer.toJson<int>(epgShiftHours),
      'reloadFrequencyHours': serializer.toJson<int>(reloadFrequencyHours),
      'userAgent': serializer.toJson<String?>(userAgent),
      'avatarId': serializer.toJson<String?>(avatarId),
      'hasAccessPin': serializer.toJson<bool>(hasAccessPin),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastReloadAt': serializer.toJson<DateTime?>(lastReloadAt),
      'lastEpgReloadAt': serializer.toJson<DateTime?>(lastEpgReloadAt),
      'accountJson': serializer.toJson<String?>(accountJson),
      'm3uHeaderJson': serializer.toJson<String?>(m3uHeaderJson),
      'liveCount': serializer.toJson<int>(liveCount),
      'movieCount': serializer.toJson<int>(movieCount),
      'seriesCount': serializer.toJson<int>(seriesCount),
      'programmeCount': serializer.toJson<int>(programmeCount),
    };
  }

  PlaylistRow copyWith({
    int? id,
    String? name,
    PlaylistType? type,
    Value<String?> server = const Value.absent(),
    Value<String?> username = const Value.absent(),
    Value<String?> m3uUrl = const Value.absent(),
    Value<String?> epgUrl = const Value.absent(),
    int? epgShiftHours,
    int? reloadFrequencyHours,
    Value<String?> userAgent = const Value.absent(),
    Value<String?> avatarId = const Value.absent(),
    bool? hasAccessPin,
    int? sortIndex,
    DateTime? createdAt,
    Value<DateTime?> lastReloadAt = const Value.absent(),
    Value<DateTime?> lastEpgReloadAt = const Value.absent(),
    Value<String?> accountJson = const Value.absent(),
    Value<String?> m3uHeaderJson = const Value.absent(),
    int? liveCount,
    int? movieCount,
    int? seriesCount,
    int? programmeCount,
  }) => PlaylistRow(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    server: server.present ? server.value : this.server,
    username: username.present ? username.value : this.username,
    m3uUrl: m3uUrl.present ? m3uUrl.value : this.m3uUrl,
    epgUrl: epgUrl.present ? epgUrl.value : this.epgUrl,
    epgShiftHours: epgShiftHours ?? this.epgShiftHours,
    reloadFrequencyHours: reloadFrequencyHours ?? this.reloadFrequencyHours,
    userAgent: userAgent.present ? userAgent.value : this.userAgent,
    avatarId: avatarId.present ? avatarId.value : this.avatarId,
    hasAccessPin: hasAccessPin ?? this.hasAccessPin,
    sortIndex: sortIndex ?? this.sortIndex,
    createdAt: createdAt ?? this.createdAt,
    lastReloadAt: lastReloadAt.present ? lastReloadAt.value : this.lastReloadAt,
    lastEpgReloadAt: lastEpgReloadAt.present
        ? lastEpgReloadAt.value
        : this.lastEpgReloadAt,
    accountJson: accountJson.present ? accountJson.value : this.accountJson,
    m3uHeaderJson: m3uHeaderJson.present
        ? m3uHeaderJson.value
        : this.m3uHeaderJson,
    liveCount: liveCount ?? this.liveCount,
    movieCount: movieCount ?? this.movieCount,
    seriesCount: seriesCount ?? this.seriesCount,
    programmeCount: programmeCount ?? this.programmeCount,
  );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      server: data.server.present ? data.server.value : this.server,
      username: data.username.present ? data.username.value : this.username,
      m3uUrl: data.m3uUrl.present ? data.m3uUrl.value : this.m3uUrl,
      epgUrl: data.epgUrl.present ? data.epgUrl.value : this.epgUrl,
      epgShiftHours: data.epgShiftHours.present
          ? data.epgShiftHours.value
          : this.epgShiftHours,
      reloadFrequencyHours: data.reloadFrequencyHours.present
          ? data.reloadFrequencyHours.value
          : this.reloadFrequencyHours,
      userAgent: data.userAgent.present ? data.userAgent.value : this.userAgent,
      avatarId: data.avatarId.present ? data.avatarId.value : this.avatarId,
      hasAccessPin: data.hasAccessPin.present
          ? data.hasAccessPin.value
          : this.hasAccessPin,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastReloadAt: data.lastReloadAt.present
          ? data.lastReloadAt.value
          : this.lastReloadAt,
      lastEpgReloadAt: data.lastEpgReloadAt.present
          ? data.lastEpgReloadAt.value
          : this.lastEpgReloadAt,
      accountJson: data.accountJson.present
          ? data.accountJson.value
          : this.accountJson,
      m3uHeaderJson: data.m3uHeaderJson.present
          ? data.m3uHeaderJson.value
          : this.m3uHeaderJson,
      liveCount: data.liveCount.present ? data.liveCount.value : this.liveCount,
      movieCount: data.movieCount.present
          ? data.movieCount.value
          : this.movieCount,
      seriesCount: data.seriesCount.present
          ? data.seriesCount.value
          : this.seriesCount,
      programmeCount: data.programmeCount.present
          ? data.programmeCount.value
          : this.programmeCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('server: $server, ')
          ..write('username: $username, ')
          ..write('m3uUrl: $m3uUrl, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('epgShiftHours: $epgShiftHours, ')
          ..write('reloadFrequencyHours: $reloadFrequencyHours, ')
          ..write('userAgent: $userAgent, ')
          ..write('avatarId: $avatarId, ')
          ..write('hasAccessPin: $hasAccessPin, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastReloadAt: $lastReloadAt, ')
          ..write('lastEpgReloadAt: $lastEpgReloadAt, ')
          ..write('accountJson: $accountJson, ')
          ..write('m3uHeaderJson: $m3uHeaderJson, ')
          ..write('liveCount: $liveCount, ')
          ..write('movieCount: $movieCount, ')
          ..write('seriesCount: $seriesCount, ')
          ..write('programmeCount: $programmeCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    type,
    server,
    username,
    m3uUrl,
    epgUrl,
    epgShiftHours,
    reloadFrequencyHours,
    userAgent,
    avatarId,
    hasAccessPin,
    sortIndex,
    createdAt,
    lastReloadAt,
    lastEpgReloadAt,
    accountJson,
    m3uHeaderJson,
    liveCount,
    movieCount,
    seriesCount,
    programmeCount,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.server == this.server &&
          other.username == this.username &&
          other.m3uUrl == this.m3uUrl &&
          other.epgUrl == this.epgUrl &&
          other.epgShiftHours == this.epgShiftHours &&
          other.reloadFrequencyHours == this.reloadFrequencyHours &&
          other.userAgent == this.userAgent &&
          other.avatarId == this.avatarId &&
          other.hasAccessPin == this.hasAccessPin &&
          other.sortIndex == this.sortIndex &&
          other.createdAt == this.createdAt &&
          other.lastReloadAt == this.lastReloadAt &&
          other.lastEpgReloadAt == this.lastEpgReloadAt &&
          other.accountJson == this.accountJson &&
          other.m3uHeaderJson == this.m3uHeaderJson &&
          other.liveCount == this.liveCount &&
          other.movieCount == this.movieCount &&
          other.seriesCount == this.seriesCount &&
          other.programmeCount == this.programmeCount);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<PlaylistType> type;
  final Value<String?> server;
  final Value<String?> username;
  final Value<String?> m3uUrl;
  final Value<String?> epgUrl;
  final Value<int> epgShiftHours;
  final Value<int> reloadFrequencyHours;
  final Value<String?> userAgent;
  final Value<String?> avatarId;
  final Value<bool> hasAccessPin;
  final Value<int> sortIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastReloadAt;
  final Value<DateTime?> lastEpgReloadAt;
  final Value<String?> accountJson;
  final Value<String?> m3uHeaderJson;
  final Value<int> liveCount;
  final Value<int> movieCount;
  final Value<int> seriesCount;
  final Value<int> programmeCount;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.server = const Value.absent(),
    this.username = const Value.absent(),
    this.m3uUrl = const Value.absent(),
    this.epgUrl = const Value.absent(),
    this.epgShiftHours = const Value.absent(),
    this.reloadFrequencyHours = const Value.absent(),
    this.userAgent = const Value.absent(),
    this.avatarId = const Value.absent(),
    this.hasAccessPin = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastReloadAt = const Value.absent(),
    this.lastEpgReloadAt = const Value.absent(),
    this.accountJson = const Value.absent(),
    this.m3uHeaderJson = const Value.absent(),
    this.liveCount = const Value.absent(),
    this.movieCount = const Value.absent(),
    this.seriesCount = const Value.absent(),
    this.programmeCount = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required PlaylistType type,
    this.server = const Value.absent(),
    this.username = const Value.absent(),
    this.m3uUrl = const Value.absent(),
    this.epgUrl = const Value.absent(),
    this.epgShiftHours = const Value.absent(),
    this.reloadFrequencyHours = const Value.absent(),
    this.userAgent = const Value.absent(),
    this.avatarId = const Value.absent(),
    this.hasAccessPin = const Value.absent(),
    this.sortIndex = const Value.absent(),
    required DateTime createdAt,
    this.lastReloadAt = const Value.absent(),
    this.lastEpgReloadAt = const Value.absent(),
    this.accountJson = const Value.absent(),
    this.m3uHeaderJson = const Value.absent(),
    this.liveCount = const Value.absent(),
    this.movieCount = const Value.absent(),
    this.seriesCount = const Value.absent(),
    this.programmeCount = const Value.absent(),
  }) : name = Value(name),
       type = Value(type),
       createdAt = Value(createdAt);
  static Insertable<PlaylistRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? type,
    Expression<String>? server,
    Expression<String>? username,
    Expression<String>? m3uUrl,
    Expression<String>? epgUrl,
    Expression<int>? epgShiftHours,
    Expression<int>? reloadFrequencyHours,
    Expression<String>? userAgent,
    Expression<String>? avatarId,
    Expression<bool>? hasAccessPin,
    Expression<int>? sortIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastReloadAt,
    Expression<DateTime>? lastEpgReloadAt,
    Expression<String>? accountJson,
    Expression<String>? m3uHeaderJson,
    Expression<int>? liveCount,
    Expression<int>? movieCount,
    Expression<int>? seriesCount,
    Expression<int>? programmeCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (server != null) 'server': server,
      if (username != null) 'username': username,
      if (m3uUrl != null) 'm3u_url': m3uUrl,
      if (epgUrl != null) 'epg_url': epgUrl,
      if (epgShiftHours != null) 'epg_shift_hours': epgShiftHours,
      if (reloadFrequencyHours != null)
        'reload_frequency_hours': reloadFrequencyHours,
      if (userAgent != null) 'user_agent': userAgent,
      if (avatarId != null) 'avatar_id': avatarId,
      if (hasAccessPin != null) 'has_access_pin': hasAccessPin,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (lastReloadAt != null) 'last_reload_at': lastReloadAt,
      if (lastEpgReloadAt != null) 'last_epg_reload_at': lastEpgReloadAt,
      if (accountJson != null) 'account_json': accountJson,
      if (m3uHeaderJson != null) 'm3u_header_json': m3uHeaderJson,
      if (liveCount != null) 'live_count': liveCount,
      if (movieCount != null) 'movie_count': movieCount,
      if (seriesCount != null) 'series_count': seriesCount,
      if (programmeCount != null) 'programme_count': programmeCount,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<PlaylistType>? type,
    Value<String?>? server,
    Value<String?>? username,
    Value<String?>? m3uUrl,
    Value<String?>? epgUrl,
    Value<int>? epgShiftHours,
    Value<int>? reloadFrequencyHours,
    Value<String?>? userAgent,
    Value<String?>? avatarId,
    Value<bool>? hasAccessPin,
    Value<int>? sortIndex,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastReloadAt,
    Value<DateTime?>? lastEpgReloadAt,
    Value<String?>? accountJson,
    Value<String?>? m3uHeaderJson,
    Value<int>? liveCount,
    Value<int>? movieCount,
    Value<int>? seriesCount,
    Value<int>? programmeCount,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      server: server ?? this.server,
      username: username ?? this.username,
      m3uUrl: m3uUrl ?? this.m3uUrl,
      epgUrl: epgUrl ?? this.epgUrl,
      epgShiftHours: epgShiftHours ?? this.epgShiftHours,
      reloadFrequencyHours: reloadFrequencyHours ?? this.reloadFrequencyHours,
      userAgent: userAgent ?? this.userAgent,
      avatarId: avatarId ?? this.avatarId,
      hasAccessPin: hasAccessPin ?? this.hasAccessPin,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt ?? this.createdAt,
      lastReloadAt: lastReloadAt ?? this.lastReloadAt,
      lastEpgReloadAt: lastEpgReloadAt ?? this.lastEpgReloadAt,
      accountJson: accountJson ?? this.accountJson,
      m3uHeaderJson: m3uHeaderJson ?? this.m3uHeaderJson,
      liveCount: liveCount ?? this.liveCount,
      movieCount: movieCount ?? this.movieCount,
      seriesCount: seriesCount ?? this.seriesCount,
      programmeCount: programmeCount ?? this.programmeCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $PlaylistsTable.$convertertype.toSql(type.value),
      );
    }
    if (server.present) {
      map['server'] = Variable<String>(server.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (m3uUrl.present) {
      map['m3u_url'] = Variable<String>(m3uUrl.value);
    }
    if (epgUrl.present) {
      map['epg_url'] = Variable<String>(epgUrl.value);
    }
    if (epgShiftHours.present) {
      map['epg_shift_hours'] = Variable<int>(epgShiftHours.value);
    }
    if (reloadFrequencyHours.present) {
      map['reload_frequency_hours'] = Variable<int>(reloadFrequencyHours.value);
    }
    if (userAgent.present) {
      map['user_agent'] = Variable<String>(userAgent.value);
    }
    if (avatarId.present) {
      map['avatar_id'] = Variable<String>(avatarId.value);
    }
    if (hasAccessPin.present) {
      map['has_access_pin'] = Variable<bool>(hasAccessPin.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastReloadAt.present) {
      map['last_reload_at'] = Variable<DateTime>(lastReloadAt.value);
    }
    if (lastEpgReloadAt.present) {
      map['last_epg_reload_at'] = Variable<DateTime>(lastEpgReloadAt.value);
    }
    if (accountJson.present) {
      map['account_json'] = Variable<String>(accountJson.value);
    }
    if (m3uHeaderJson.present) {
      map['m3u_header_json'] = Variable<String>(m3uHeaderJson.value);
    }
    if (liveCount.present) {
      map['live_count'] = Variable<int>(liveCount.value);
    }
    if (movieCount.present) {
      map['movie_count'] = Variable<int>(movieCount.value);
    }
    if (seriesCount.present) {
      map['series_count'] = Variable<int>(seriesCount.value);
    }
    if (programmeCount.present) {
      map['programme_count'] = Variable<int>(programmeCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('server: $server, ')
          ..write('username: $username, ')
          ..write('m3uUrl: $m3uUrl, ')
          ..write('epgUrl: $epgUrl, ')
          ..write('epgShiftHours: $epgShiftHours, ')
          ..write('reloadFrequencyHours: $reloadFrequencyHours, ')
          ..write('userAgent: $userAgent, ')
          ..write('avatarId: $avatarId, ')
          ..write('hasAccessPin: $hasAccessPin, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastReloadAt: $lastReloadAt, ')
          ..write('lastEpgReloadAt: $lastEpgReloadAt, ')
          ..write('accountJson: $accountJson, ')
          ..write('m3uHeaderJson: $m3uHeaderJson, ')
          ..write('liveCount: $liveCount, ')
          ..write('movieCount: $movieCount, ')
          ..write('seriesCount: $seriesCount, ')
          ..write('programmeCount: $programmeCount')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<SectionKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SectionKind>($CategoriesTable.$converterkind);
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localNameMeta = const VerificationMeta(
    'localName',
  );
  @override
  late final GeneratedColumn<String> localName = GeneratedColumn<String>(
    'local_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _customIndexMeta = const VerificationMeta(
    'customIndex',
  );
  @override
  late final GeneratedColumn<int> customIndex = GeneratedColumn<int>(
    'custom_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _removedMeta = const VerificationMeta(
    'removed',
  );
  @override
  late final GeneratedColumn<bool> removed = GeneratedColumn<bool>(
    'removed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("removed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    kind,
    providerId,
    name,
    localName,
    parentId,
    sortIndex,
    customIndex,
    hidden,
    locked,
    removed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('local_name')) {
      context.handle(
        _localNameMeta,
        localName.isAcceptableOrUnknown(data['local_name']!, _localNameMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('custom_index')) {
      context.handle(
        _customIndexMeta,
        customIndex.isAcceptableOrUnknown(
          data['custom_index']!,
          _customIndexMeta,
        ),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('removed')) {
      context.handle(
        _removedMeta,
        removed.isAcceptableOrUnknown(data['removed']!, _removedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, kind, providerId},
  ];
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      kind: $CategoriesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      localName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_name'],
      ),
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      customIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_index'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
      removed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}removed'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SectionKind, int, int> $converterkind =
      const EnumIndexConverter<SectionKind>(SectionKind.values);
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final int id;
  final int playlistId;
  final SectionKind kind;
  final String providerId;
  final String name;

  /// Local rename (survives reloads). Null = use [name].
  final String? localName;
  final String? parentId;

  /// Provider order.
  final int sortIndex;

  /// Custom order (null = not customized).
  final int? customIndex;
  final bool hidden;
  final bool locked;

  /// Set during an incremental import when the item disappeared upstream.
  final bool removed;
  const CategoryRow({
    required this.id,
    required this.playlistId,
    required this.kind,
    required this.providerId,
    required this.name,
    this.localName,
    this.parentId,
    required this.sortIndex,
    this.customIndex,
    required this.hidden,
    required this.locked,
    required this.removed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    {
      map['kind'] = Variable<int>($CategoriesTable.$converterkind.toSql(kind));
    }
    map['provider_id'] = Variable<String>(providerId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || localName != null) {
      map['local_name'] = Variable<String>(localName);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    if (!nullToAbsent || customIndex != null) {
      map['custom_index'] = Variable<int>(customIndex);
    }
    map['hidden'] = Variable<bool>(hidden);
    map['locked'] = Variable<bool>(locked);
    map['removed'] = Variable<bool>(removed);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      kind: Value(kind),
      providerId: Value(providerId),
      name: Value(name),
      localName: localName == null && nullToAbsent
          ? const Value.absent()
          : Value(localName),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sortIndex: Value(sortIndex),
      customIndex: customIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(customIndex),
      hidden: Value(hidden),
      locked: Value(locked),
      removed: Value(removed),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      kind: $CategoriesTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      providerId: serializer.fromJson<String>(json['providerId']),
      name: serializer.fromJson<String>(json['name']),
      localName: serializer.fromJson<String?>(json['localName']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      customIndex: serializer.fromJson<int?>(json['customIndex']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      locked: serializer.fromJson<bool>(json['locked']),
      removed: serializer.fromJson<bool>(json['removed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'kind': serializer.toJson<int>(
        $CategoriesTable.$converterkind.toJson(kind),
      ),
      'providerId': serializer.toJson<String>(providerId),
      'name': serializer.toJson<String>(name),
      'localName': serializer.toJson<String?>(localName),
      'parentId': serializer.toJson<String?>(parentId),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'customIndex': serializer.toJson<int?>(customIndex),
      'hidden': serializer.toJson<bool>(hidden),
      'locked': serializer.toJson<bool>(locked),
      'removed': serializer.toJson<bool>(removed),
    };
  }

  CategoryRow copyWith({
    int? id,
    int? playlistId,
    SectionKind? kind,
    String? providerId,
    String? name,
    Value<String?> localName = const Value.absent(),
    Value<String?> parentId = const Value.absent(),
    int? sortIndex,
    Value<int?> customIndex = const Value.absent(),
    bool? hidden,
    bool? locked,
    bool? removed,
  }) => CategoryRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    kind: kind ?? this.kind,
    providerId: providerId ?? this.providerId,
    name: name ?? this.name,
    localName: localName.present ? localName.value : this.localName,
    parentId: parentId.present ? parentId.value : this.parentId,
    sortIndex: sortIndex ?? this.sortIndex,
    customIndex: customIndex.present ? customIndex.value : this.customIndex,
    hidden: hidden ?? this.hidden,
    locked: locked ?? this.locked,
    removed: removed ?? this.removed,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      kind: data.kind.present ? data.kind.value : this.kind,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      name: data.name.present ? data.name.value : this.name,
      localName: data.localName.present ? data.localName.value : this.localName,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      customIndex: data.customIndex.present
          ? data.customIndex.value
          : this.customIndex,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      locked: data.locked.present ? data.locked.value : this.locked,
      removed: data.removed.present ? data.removed.value : this.removed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('kind: $kind, ')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('localName: $localName, ')
          ..write('parentId: $parentId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('customIndex: $customIndex, ')
          ..write('hidden: $hidden, ')
          ..write('locked: $locked, ')
          ..write('removed: $removed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    kind,
    providerId,
    name,
    localName,
    parentId,
    sortIndex,
    customIndex,
    hidden,
    locked,
    removed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.kind == this.kind &&
          other.providerId == this.providerId &&
          other.name == this.name &&
          other.localName == this.localName &&
          other.parentId == this.parentId &&
          other.sortIndex == this.sortIndex &&
          other.customIndex == this.customIndex &&
          other.hidden == this.hidden &&
          other.locked == this.locked &&
          other.removed == this.removed);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<SectionKind> kind;
  final Value<String> providerId;
  final Value<String> name;
  final Value<String?> localName;
  final Value<String?> parentId;
  final Value<int> sortIndex;
  final Value<int?> customIndex;
  final Value<bool> hidden;
  final Value<bool> locked;
  final Value<bool> removed;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.kind = const Value.absent(),
    this.providerId = const Value.absent(),
    this.name = const Value.absent(),
    this.localName = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.customIndex = const Value.absent(),
    this.hidden = const Value.absent(),
    this.locked = const Value.absent(),
    this.removed = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required SectionKind kind,
    required String providerId,
    required String name,
    this.localName = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.customIndex = const Value.absent(),
    this.hidden = const Value.absent(),
    this.locked = const Value.absent(),
    this.removed = const Value.absent(),
  }) : playlistId = Value(playlistId),
       kind = Value(kind),
       providerId = Value(providerId),
       name = Value(name);
  static Insertable<CategoryRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<int>? kind,
    Expression<String>? providerId,
    Expression<String>? name,
    Expression<String>? localName,
    Expression<String>? parentId,
    Expression<int>? sortIndex,
    Expression<int>? customIndex,
    Expression<bool>? hidden,
    Expression<bool>? locked,
    Expression<bool>? removed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (kind != null) 'kind': kind,
      if (providerId != null) 'provider_id': providerId,
      if (name != null) 'name': name,
      if (localName != null) 'local_name': localName,
      if (parentId != null) 'parent_id': parentId,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (customIndex != null) 'custom_index': customIndex,
      if (hidden != null) 'hidden': hidden,
      if (locked != null) 'locked': locked,
      if (removed != null) 'removed': removed,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<SectionKind>? kind,
    Value<String>? providerId,
    Value<String>? name,
    Value<String?>? localName,
    Value<String?>? parentId,
    Value<int>? sortIndex,
    Value<int?>? customIndex,
    Value<bool>? hidden,
    Value<bool>? locked,
    Value<bool>? removed,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      kind: kind ?? this.kind,
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      localName: localName ?? this.localName,
      parentId: parentId ?? this.parentId,
      sortIndex: sortIndex ?? this.sortIndex,
      customIndex: customIndex ?? this.customIndex,
      hidden: hidden ?? this.hidden,
      locked: locked ?? this.locked,
      removed: removed ?? this.removed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $CategoriesTable.$converterkind.toSql(kind.value),
      );
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (localName.present) {
      map['local_name'] = Variable<String>(localName.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (customIndex.present) {
      map['custom_index'] = Variable<int>(customIndex.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (removed.present) {
      map['removed'] = Variable<bool>(removed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('kind: $kind, ')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('localName: $localName, ')
          ..write('parentId: $parentId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('customIndex: $customIndex, ')
          ..write('hidden: $hidden, ')
          ..write('locked: $locked, ')
          ..write('removed: $removed')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTable extends Channels
    with TableInfo<$ChannelsTable, ChannelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numMeta = const VerificationMeta('num');
  @override
  late final GeneratedColumn<int> num = GeneratedColumn<int>(
    'num',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoMeta = const VerificationMeta('logo');
  @override
  late final GeneratedColumn<String> logo = GeneratedColumn<String>(
    'logo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epgIdMeta = const VerificationMeta('epgId');
  @override
  late final GeneratedColumn<String> epgId = GeneratedColumn<String>(
    'epg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _matchedEpgIdMeta = const VerificationMeta(
    'matchedEpgId',
  );
  @override
  late final GeneratedColumn<String> matchedEpgId = GeneratedColumn<String>(
    'matched_epg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customEpgIdMeta = const VerificationMeta(
    'customEpgId',
  );
  @override
  late final GeneratedColumn<String> customEpgId = GeneratedColumn<String>(
    'custom_epg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archiveDaysMeta = const VerificationMeta(
    'archiveDays',
  );
  @override
  late final GeneratedColumn<int> archiveDays = GeneratedColumn<int>(
    'archive_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _catchupTypeMeta = const VerificationMeta(
    'catchupType',
  );
  @override
  late final GeneratedColumn<String> catchupType = GeneratedColumn<String>(
    'catchup_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _catchupSourceMeta = const VerificationMeta(
    'catchupSource',
  );
  @override
  late final GeneratedColumn<String> catchupSource = GeneratedColumn<String>(
    'catchup_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directSourceMeta = const VerificationMeta(
    'directSource',
  );
  @override
  late final GeneratedColumn<String> directSource = GeneratedColumn<String>(
    'direct_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headersJsonMeta = const VerificationMeta(
    'headersJson',
  );
  @override
  late final GeneratedColumn<String> headersJson = GeneratedColumn<String>(
    'headers_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unsupportedMeta = const VerificationMeta(
    'unsupported',
  );
  @override
  late final GeneratedColumn<bool> unsupported = GeneratedColumn<bool>(
    'unsupported',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unsupported" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<DateTime> added = GeneratedColumn<DateTime>(
    'added',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _customIndexMeta = const VerificationMeta(
    'customIndex',
  );
  @override
  late final GeneratedColumn<int> customIndex = GeneratedColumn<int>(
    'custom_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lockedMeta = const VerificationMeta('locked');
  @override
  late final GeneratedColumn<bool> locked = GeneratedColumn<bool>(
    'locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _removedMeta = const VerificationMeta(
    'removed',
  );
  @override
  late final GeneratedColumn<bool> removed = GeneratedColumn<bool>(
    'removed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("removed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    providerId,
    num,
    name,
    displayName,
    quality,
    logo,
    categoryId,
    epgId,
    matchedEpgId,
    customEpgId,
    archiveDays,
    catchupType,
    catchupSource,
    streamUrl,
    directSource,
    headersJson,
    unsupported,
    added,
    sortIndex,
    customIndex,
    hidden,
    locked,
    removed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChannelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('num')) {
      context.handle(
        _numMeta,
        num.isAcceptableOrUnknown(data['num']!, _numMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('logo')) {
      context.handle(
        _logoMeta,
        logo.isAcceptableOrUnknown(data['logo']!, _logoMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('epg_id')) {
      context.handle(
        _epgIdMeta,
        epgId.isAcceptableOrUnknown(data['epg_id']!, _epgIdMeta),
      );
    }
    if (data.containsKey('matched_epg_id')) {
      context.handle(
        _matchedEpgIdMeta,
        matchedEpgId.isAcceptableOrUnknown(
          data['matched_epg_id']!,
          _matchedEpgIdMeta,
        ),
      );
    }
    if (data.containsKey('custom_epg_id')) {
      context.handle(
        _customEpgIdMeta,
        customEpgId.isAcceptableOrUnknown(
          data['custom_epg_id']!,
          _customEpgIdMeta,
        ),
      );
    }
    if (data.containsKey('archive_days')) {
      context.handle(
        _archiveDaysMeta,
        archiveDays.isAcceptableOrUnknown(
          data['archive_days']!,
          _archiveDaysMeta,
        ),
      );
    }
    if (data.containsKey('catchup_type')) {
      context.handle(
        _catchupTypeMeta,
        catchupType.isAcceptableOrUnknown(
          data['catchup_type']!,
          _catchupTypeMeta,
        ),
      );
    }
    if (data.containsKey('catchup_source')) {
      context.handle(
        _catchupSourceMeta,
        catchupSource.isAcceptableOrUnknown(
          data['catchup_source']!,
          _catchupSourceMeta,
        ),
      );
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    }
    if (data.containsKey('direct_source')) {
      context.handle(
        _directSourceMeta,
        directSource.isAcceptableOrUnknown(
          data['direct_source']!,
          _directSourceMeta,
        ),
      );
    }
    if (data.containsKey('headers_json')) {
      context.handle(
        _headersJsonMeta,
        headersJson.isAcceptableOrUnknown(
          data['headers_json']!,
          _headersJsonMeta,
        ),
      );
    }
    if (data.containsKey('unsupported')) {
      context.handle(
        _unsupportedMeta,
        unsupported.isAcceptableOrUnknown(
          data['unsupported']!,
          _unsupportedMeta,
        ),
      );
    }
    if (data.containsKey('added')) {
      context.handle(
        _addedMeta,
        added.isAcceptableOrUnknown(data['added']!, _addedMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('custom_index')) {
      context.handle(
        _customIndexMeta,
        customIndex.isAcceptableOrUnknown(
          data['custom_index']!,
          _customIndexMeta,
        ),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('locked')) {
      context.handle(
        _lockedMeta,
        locked.isAcceptableOrUnknown(data['locked']!, _lockedMeta),
      );
    }
    if (data.containsKey('removed')) {
      context.handle(
        _removedMeta,
        removed.isAcceptableOrUnknown(data['removed']!, _removedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, providerId},
  ];
  @override
  ChannelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChannelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      num: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}num'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality'],
      ),
      logo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      epgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_id'],
      ),
      matchedEpgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matched_epg_id'],
      ),
      customEpgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_epg_id'],
      ),
      archiveDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archive_days'],
      )!,
      catchupType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catchup_type'],
      ),
      catchupSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catchup_source'],
      ),
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      ),
      directSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direct_source'],
      ),
      headersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headers_json'],
      ),
      unsupported: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unsupported'],
      )!,
      added: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      customIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_index'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      locked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}locked'],
      )!,
      removed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}removed'],
      )!,
    );
  }

  @override
  $ChannelsTable createAlias(String alias) {
    return $ChannelsTable(attachedDatabase, alias);
  }
}

class ChannelRow extends DataClass implements Insertable<ChannelRow> {
  final int id;
  final int playlistId;

  /// Xtream stream_id, or a stable hash for M3U entries.
  final String providerId;
  final int? num;

  /// Name as delivered by the provider.
  final String name;

  /// Name with quality tokens stripped (what the UI shows).
  final String displayName;

  /// Quality badge parsed from the name: SD, HD, FHD, 4K, H265, HEVC, 50FPS.
  final String? quality;
  final String? logo;

  /// Provider category id (matches [Categories.providerId] with kind live).
  final String? categoryId;

  /// tvg-id / epg_channel_id from the provider.
  final String? epgId;

  /// Result of the EPG matcher (xmltv channel id), refreshed on EPG import.
  final String? matchedEpgId;

  /// Manual Custom EPG assignment (survives reloads, wins over matching).
  final String? customEpgId;

  /// Catch-up window in days (0 = no archive).
  final int archiveDays;

  /// M3U catch-up mode (default/append/shift/flussonic/xc) and source.
  final String? catchupType;
  final String? catchupSource;

  /// Full stream URL (M3U) — null for Xtream (built from providerId).
  final String? streamUrl;
  final String? directSource;

  /// Per-entry HTTP headers JSON ({"User-Agent":…,"Referer":…}).
  final String? headersJson;

  /// Entry needs DRM (KODIPROP license) — shown but not playable.
  final bool unsupported;
  final DateTime? added;
  final int sortIndex;
  final int? customIndex;
  final bool hidden;
  final bool locked;
  final bool removed;
  const ChannelRow({
    required this.id,
    required this.playlistId,
    required this.providerId,
    this.num,
    required this.name,
    required this.displayName,
    this.quality,
    this.logo,
    this.categoryId,
    this.epgId,
    this.matchedEpgId,
    this.customEpgId,
    required this.archiveDays,
    this.catchupType,
    this.catchupSource,
    this.streamUrl,
    this.directSource,
    this.headersJson,
    required this.unsupported,
    this.added,
    required this.sortIndex,
    this.customIndex,
    required this.hidden,
    required this.locked,
    required this.removed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['provider_id'] = Variable<String>(providerId);
    if (!nullToAbsent || num != null) {
      map['num'] = Variable<int>(num);
    }
    map['name'] = Variable<String>(name);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<String>(quality);
    }
    if (!nullToAbsent || logo != null) {
      map['logo'] = Variable<String>(logo);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || epgId != null) {
      map['epg_id'] = Variable<String>(epgId);
    }
    if (!nullToAbsent || matchedEpgId != null) {
      map['matched_epg_id'] = Variable<String>(matchedEpgId);
    }
    if (!nullToAbsent || customEpgId != null) {
      map['custom_epg_id'] = Variable<String>(customEpgId);
    }
    map['archive_days'] = Variable<int>(archiveDays);
    if (!nullToAbsent || catchupType != null) {
      map['catchup_type'] = Variable<String>(catchupType);
    }
    if (!nullToAbsent || catchupSource != null) {
      map['catchup_source'] = Variable<String>(catchupSource);
    }
    if (!nullToAbsent || streamUrl != null) {
      map['stream_url'] = Variable<String>(streamUrl);
    }
    if (!nullToAbsent || directSource != null) {
      map['direct_source'] = Variable<String>(directSource);
    }
    if (!nullToAbsent || headersJson != null) {
      map['headers_json'] = Variable<String>(headersJson);
    }
    map['unsupported'] = Variable<bool>(unsupported);
    if (!nullToAbsent || added != null) {
      map['added'] = Variable<DateTime>(added);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    if (!nullToAbsent || customIndex != null) {
      map['custom_index'] = Variable<int>(customIndex);
    }
    map['hidden'] = Variable<bool>(hidden);
    map['locked'] = Variable<bool>(locked);
    map['removed'] = Variable<bool>(removed);
    return map;
  }

  ChannelsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      providerId: Value(providerId),
      num: num == null && nullToAbsent ? const Value.absent() : Value(num),
      name: Value(name),
      displayName: Value(displayName),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      logo: logo == null && nullToAbsent ? const Value.absent() : Value(logo),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      epgId: epgId == null && nullToAbsent
          ? const Value.absent()
          : Value(epgId),
      matchedEpgId: matchedEpgId == null && nullToAbsent
          ? const Value.absent()
          : Value(matchedEpgId),
      customEpgId: customEpgId == null && nullToAbsent
          ? const Value.absent()
          : Value(customEpgId),
      archiveDays: Value(archiveDays),
      catchupType: catchupType == null && nullToAbsent
          ? const Value.absent()
          : Value(catchupType),
      catchupSource: catchupSource == null && nullToAbsent
          ? const Value.absent()
          : Value(catchupSource),
      streamUrl: streamUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(streamUrl),
      directSource: directSource == null && nullToAbsent
          ? const Value.absent()
          : Value(directSource),
      headersJson: headersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(headersJson),
      unsupported: Value(unsupported),
      added: added == null && nullToAbsent
          ? const Value.absent()
          : Value(added),
      sortIndex: Value(sortIndex),
      customIndex: customIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(customIndex),
      hidden: Value(hidden),
      locked: Value(locked),
      removed: Value(removed),
    );
  }

  factory ChannelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChannelRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      num: serializer.fromJson<int?>(json['num']),
      name: serializer.fromJson<String>(json['name']),
      displayName: serializer.fromJson<String>(json['displayName']),
      quality: serializer.fromJson<String?>(json['quality']),
      logo: serializer.fromJson<String?>(json['logo']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      epgId: serializer.fromJson<String?>(json['epgId']),
      matchedEpgId: serializer.fromJson<String?>(json['matchedEpgId']),
      customEpgId: serializer.fromJson<String?>(json['customEpgId']),
      archiveDays: serializer.fromJson<int>(json['archiveDays']),
      catchupType: serializer.fromJson<String?>(json['catchupType']),
      catchupSource: serializer.fromJson<String?>(json['catchupSource']),
      streamUrl: serializer.fromJson<String?>(json['streamUrl']),
      directSource: serializer.fromJson<String?>(json['directSource']),
      headersJson: serializer.fromJson<String?>(json['headersJson']),
      unsupported: serializer.fromJson<bool>(json['unsupported']),
      added: serializer.fromJson<DateTime?>(json['added']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      customIndex: serializer.fromJson<int?>(json['customIndex']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      locked: serializer.fromJson<bool>(json['locked']),
      removed: serializer.fromJson<bool>(json['removed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'providerId': serializer.toJson<String>(providerId),
      'num': serializer.toJson<int?>(num),
      'name': serializer.toJson<String>(name),
      'displayName': serializer.toJson<String>(displayName),
      'quality': serializer.toJson<String?>(quality),
      'logo': serializer.toJson<String?>(logo),
      'categoryId': serializer.toJson<String?>(categoryId),
      'epgId': serializer.toJson<String?>(epgId),
      'matchedEpgId': serializer.toJson<String?>(matchedEpgId),
      'customEpgId': serializer.toJson<String?>(customEpgId),
      'archiveDays': serializer.toJson<int>(archiveDays),
      'catchupType': serializer.toJson<String?>(catchupType),
      'catchupSource': serializer.toJson<String?>(catchupSource),
      'streamUrl': serializer.toJson<String?>(streamUrl),
      'directSource': serializer.toJson<String?>(directSource),
      'headersJson': serializer.toJson<String?>(headersJson),
      'unsupported': serializer.toJson<bool>(unsupported),
      'added': serializer.toJson<DateTime?>(added),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'customIndex': serializer.toJson<int?>(customIndex),
      'hidden': serializer.toJson<bool>(hidden),
      'locked': serializer.toJson<bool>(locked),
      'removed': serializer.toJson<bool>(removed),
    };
  }

  ChannelRow copyWith({
    int? id,
    int? playlistId,
    String? providerId,
    Value<int?> num = const Value.absent(),
    String? name,
    String? displayName,
    Value<String?> quality = const Value.absent(),
    Value<String?> logo = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> epgId = const Value.absent(),
    Value<String?> matchedEpgId = const Value.absent(),
    Value<String?> customEpgId = const Value.absent(),
    int? archiveDays,
    Value<String?> catchupType = const Value.absent(),
    Value<String?> catchupSource = const Value.absent(),
    Value<String?> streamUrl = const Value.absent(),
    Value<String?> directSource = const Value.absent(),
    Value<String?> headersJson = const Value.absent(),
    bool? unsupported,
    Value<DateTime?> added = const Value.absent(),
    int? sortIndex,
    Value<int?> customIndex = const Value.absent(),
    bool? hidden,
    bool? locked,
    bool? removed,
  }) => ChannelRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    providerId: providerId ?? this.providerId,
    num: num.present ? num.value : this.num,
    name: name ?? this.name,
    displayName: displayName ?? this.displayName,
    quality: quality.present ? quality.value : this.quality,
    logo: logo.present ? logo.value : this.logo,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    epgId: epgId.present ? epgId.value : this.epgId,
    matchedEpgId: matchedEpgId.present ? matchedEpgId.value : this.matchedEpgId,
    customEpgId: customEpgId.present ? customEpgId.value : this.customEpgId,
    archiveDays: archiveDays ?? this.archiveDays,
    catchupType: catchupType.present ? catchupType.value : this.catchupType,
    catchupSource: catchupSource.present
        ? catchupSource.value
        : this.catchupSource,
    streamUrl: streamUrl.present ? streamUrl.value : this.streamUrl,
    directSource: directSource.present ? directSource.value : this.directSource,
    headersJson: headersJson.present ? headersJson.value : this.headersJson,
    unsupported: unsupported ?? this.unsupported,
    added: added.present ? added.value : this.added,
    sortIndex: sortIndex ?? this.sortIndex,
    customIndex: customIndex.present ? customIndex.value : this.customIndex,
    hidden: hidden ?? this.hidden,
    locked: locked ?? this.locked,
    removed: removed ?? this.removed,
  );
  ChannelRow copyWithCompanion(ChannelsCompanion data) {
    return ChannelRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      num: data.num.present ? data.num.value : this.num,
      name: data.name.present ? data.name.value : this.name,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      quality: data.quality.present ? data.quality.value : this.quality,
      logo: data.logo.present ? data.logo.value : this.logo,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      epgId: data.epgId.present ? data.epgId.value : this.epgId,
      matchedEpgId: data.matchedEpgId.present
          ? data.matchedEpgId.value
          : this.matchedEpgId,
      customEpgId: data.customEpgId.present
          ? data.customEpgId.value
          : this.customEpgId,
      archiveDays: data.archiveDays.present
          ? data.archiveDays.value
          : this.archiveDays,
      catchupType: data.catchupType.present
          ? data.catchupType.value
          : this.catchupType,
      catchupSource: data.catchupSource.present
          ? data.catchupSource.value
          : this.catchupSource,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      directSource: data.directSource.present
          ? data.directSource.value
          : this.directSource,
      headersJson: data.headersJson.present
          ? data.headersJson.value
          : this.headersJson,
      unsupported: data.unsupported.present
          ? data.unsupported.value
          : this.unsupported,
      added: data.added.present ? data.added.value : this.added,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      customIndex: data.customIndex.present
          ? data.customIndex.value
          : this.customIndex,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      locked: data.locked.present ? data.locked.value : this.locked,
      removed: data.removed.present ? data.removed.value : this.removed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChannelRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('providerId: $providerId, ')
          ..write('num: $num, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('quality: $quality, ')
          ..write('logo: $logo, ')
          ..write('categoryId: $categoryId, ')
          ..write('epgId: $epgId, ')
          ..write('matchedEpgId: $matchedEpgId, ')
          ..write('customEpgId: $customEpgId, ')
          ..write('archiveDays: $archiveDays, ')
          ..write('catchupType: $catchupType, ')
          ..write('catchupSource: $catchupSource, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('directSource: $directSource, ')
          ..write('headersJson: $headersJson, ')
          ..write('unsupported: $unsupported, ')
          ..write('added: $added, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('customIndex: $customIndex, ')
          ..write('hidden: $hidden, ')
          ..write('locked: $locked, ')
          ..write('removed: $removed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    playlistId,
    providerId,
    num,
    name,
    displayName,
    quality,
    logo,
    categoryId,
    epgId,
    matchedEpgId,
    customEpgId,
    archiveDays,
    catchupType,
    catchupSource,
    streamUrl,
    directSource,
    headersJson,
    unsupported,
    added,
    sortIndex,
    customIndex,
    hidden,
    locked,
    removed,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChannelRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.providerId == this.providerId &&
          other.num == this.num &&
          other.name == this.name &&
          other.displayName == this.displayName &&
          other.quality == this.quality &&
          other.logo == this.logo &&
          other.categoryId == this.categoryId &&
          other.epgId == this.epgId &&
          other.matchedEpgId == this.matchedEpgId &&
          other.customEpgId == this.customEpgId &&
          other.archiveDays == this.archiveDays &&
          other.catchupType == this.catchupType &&
          other.catchupSource == this.catchupSource &&
          other.streamUrl == this.streamUrl &&
          other.directSource == this.directSource &&
          other.headersJson == this.headersJson &&
          other.unsupported == this.unsupported &&
          other.added == this.added &&
          other.sortIndex == this.sortIndex &&
          other.customIndex == this.customIndex &&
          other.hidden == this.hidden &&
          other.locked == this.locked &&
          other.removed == this.removed);
}

class ChannelsCompanion extends UpdateCompanion<ChannelRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> providerId;
  final Value<int?> num;
  final Value<String> name;
  final Value<String> displayName;
  final Value<String?> quality;
  final Value<String?> logo;
  final Value<String?> categoryId;
  final Value<String?> epgId;
  final Value<String?> matchedEpgId;
  final Value<String?> customEpgId;
  final Value<int> archiveDays;
  final Value<String?> catchupType;
  final Value<String?> catchupSource;
  final Value<String?> streamUrl;
  final Value<String?> directSource;
  final Value<String?> headersJson;
  final Value<bool> unsupported;
  final Value<DateTime?> added;
  final Value<int> sortIndex;
  final Value<int?> customIndex;
  final Value<bool> hidden;
  final Value<bool> locked;
  final Value<bool> removed;
  const ChannelsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.num = const Value.absent(),
    this.name = const Value.absent(),
    this.displayName = const Value.absent(),
    this.quality = const Value.absent(),
    this.logo = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.epgId = const Value.absent(),
    this.matchedEpgId = const Value.absent(),
    this.customEpgId = const Value.absent(),
    this.archiveDays = const Value.absent(),
    this.catchupType = const Value.absent(),
    this.catchupSource = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.directSource = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.unsupported = const Value.absent(),
    this.added = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.customIndex = const Value.absent(),
    this.hidden = const Value.absent(),
    this.locked = const Value.absent(),
    this.removed = const Value.absent(),
  });
  ChannelsCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String providerId,
    this.num = const Value.absent(),
    required String name,
    required String displayName,
    this.quality = const Value.absent(),
    this.logo = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.epgId = const Value.absent(),
    this.matchedEpgId = const Value.absent(),
    this.customEpgId = const Value.absent(),
    this.archiveDays = const Value.absent(),
    this.catchupType = const Value.absent(),
    this.catchupSource = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.directSource = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.unsupported = const Value.absent(),
    this.added = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.customIndex = const Value.absent(),
    this.hidden = const Value.absent(),
    this.locked = const Value.absent(),
    this.removed = const Value.absent(),
  }) : playlistId = Value(playlistId),
       providerId = Value(providerId),
       name = Value(name),
       displayName = Value(displayName);
  static Insertable<ChannelRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? providerId,
    Expression<int>? num,
    Expression<String>? name,
    Expression<String>? displayName,
    Expression<String>? quality,
    Expression<String>? logo,
    Expression<String>? categoryId,
    Expression<String>? epgId,
    Expression<String>? matchedEpgId,
    Expression<String>? customEpgId,
    Expression<int>? archiveDays,
    Expression<String>? catchupType,
    Expression<String>? catchupSource,
    Expression<String>? streamUrl,
    Expression<String>? directSource,
    Expression<String>? headersJson,
    Expression<bool>? unsupported,
    Expression<DateTime>? added,
    Expression<int>? sortIndex,
    Expression<int>? customIndex,
    Expression<bool>? hidden,
    Expression<bool>? locked,
    Expression<bool>? removed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (providerId != null) 'provider_id': providerId,
      if (num != null) 'num': num,
      if (name != null) 'name': name,
      if (displayName != null) 'display_name': displayName,
      if (quality != null) 'quality': quality,
      if (logo != null) 'logo': logo,
      if (categoryId != null) 'category_id': categoryId,
      if (epgId != null) 'epg_id': epgId,
      if (matchedEpgId != null) 'matched_epg_id': matchedEpgId,
      if (customEpgId != null) 'custom_epg_id': customEpgId,
      if (archiveDays != null) 'archive_days': archiveDays,
      if (catchupType != null) 'catchup_type': catchupType,
      if (catchupSource != null) 'catchup_source': catchupSource,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (directSource != null) 'direct_source': directSource,
      if (headersJson != null) 'headers_json': headersJson,
      if (unsupported != null) 'unsupported': unsupported,
      if (added != null) 'added': added,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (customIndex != null) 'custom_index': customIndex,
      if (hidden != null) 'hidden': hidden,
      if (locked != null) 'locked': locked,
      if (removed != null) 'removed': removed,
    });
  }

  ChannelsCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? providerId,
    Value<int?>? num,
    Value<String>? name,
    Value<String>? displayName,
    Value<String?>? quality,
    Value<String?>? logo,
    Value<String?>? categoryId,
    Value<String?>? epgId,
    Value<String?>? matchedEpgId,
    Value<String?>? customEpgId,
    Value<int>? archiveDays,
    Value<String?>? catchupType,
    Value<String?>? catchupSource,
    Value<String?>? streamUrl,
    Value<String?>? directSource,
    Value<String?>? headersJson,
    Value<bool>? unsupported,
    Value<DateTime?>? added,
    Value<int>? sortIndex,
    Value<int?>? customIndex,
    Value<bool>? hidden,
    Value<bool>? locked,
    Value<bool>? removed,
  }) {
    return ChannelsCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      providerId: providerId ?? this.providerId,
      num: num ?? this.num,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      quality: quality ?? this.quality,
      logo: logo ?? this.logo,
      categoryId: categoryId ?? this.categoryId,
      epgId: epgId ?? this.epgId,
      matchedEpgId: matchedEpgId ?? this.matchedEpgId,
      customEpgId: customEpgId ?? this.customEpgId,
      archiveDays: archiveDays ?? this.archiveDays,
      catchupType: catchupType ?? this.catchupType,
      catchupSource: catchupSource ?? this.catchupSource,
      streamUrl: streamUrl ?? this.streamUrl,
      directSource: directSource ?? this.directSource,
      headersJson: headersJson ?? this.headersJson,
      unsupported: unsupported ?? this.unsupported,
      added: added ?? this.added,
      sortIndex: sortIndex ?? this.sortIndex,
      customIndex: customIndex ?? this.customIndex,
      hidden: hidden ?? this.hidden,
      locked: locked ?? this.locked,
      removed: removed ?? this.removed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (num.present) {
      map['num'] = Variable<int>(num.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (logo.present) {
      map['logo'] = Variable<String>(logo.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (epgId.present) {
      map['epg_id'] = Variable<String>(epgId.value);
    }
    if (matchedEpgId.present) {
      map['matched_epg_id'] = Variable<String>(matchedEpgId.value);
    }
    if (customEpgId.present) {
      map['custom_epg_id'] = Variable<String>(customEpgId.value);
    }
    if (archiveDays.present) {
      map['archive_days'] = Variable<int>(archiveDays.value);
    }
    if (catchupType.present) {
      map['catchup_type'] = Variable<String>(catchupType.value);
    }
    if (catchupSource.present) {
      map['catchup_source'] = Variable<String>(catchupSource.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (directSource.present) {
      map['direct_source'] = Variable<String>(directSource.value);
    }
    if (headersJson.present) {
      map['headers_json'] = Variable<String>(headersJson.value);
    }
    if (unsupported.present) {
      map['unsupported'] = Variable<bool>(unsupported.value);
    }
    if (added.present) {
      map['added'] = Variable<DateTime>(added.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (customIndex.present) {
      map['custom_index'] = Variable<int>(customIndex.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (locked.present) {
      map['locked'] = Variable<bool>(locked.value);
    }
    if (removed.present) {
      map['removed'] = Variable<bool>(removed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('providerId: $providerId, ')
          ..write('num: $num, ')
          ..write('name: $name, ')
          ..write('displayName: $displayName, ')
          ..write('quality: $quality, ')
          ..write('logo: $logo, ')
          ..write('categoryId: $categoryId, ')
          ..write('epgId: $epgId, ')
          ..write('matchedEpgId: $matchedEpgId, ')
          ..write('customEpgId: $customEpgId, ')
          ..write('archiveDays: $archiveDays, ')
          ..write('catchupType: $catchupType, ')
          ..write('catchupSource: $catchupSource, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('directSource: $directSource, ')
          ..write('headersJson: $headersJson, ')
          ..write('unsupported: $unsupported, ')
          ..write('added: $added, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('customIndex: $customIndex, ')
          ..write('hidden: $hidden, ')
          ..write('locked: $locked, ')
          ..write('removed: $removed')
          ..write(')'))
        .toString();
  }
}

class $MoviesTable extends Movies with TableInfo<$MoviesTable, MovieRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoviesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posterMeta = const VerificationMeta('poster');
  @override
  late final GeneratedColumn<String> poster = GeneratedColumn<String>(
    'poster',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<DateTime> added = GeneratedColumn<DateTime>(
    'added',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _containerExtMeta = const VerificationMeta(
    'containerExt',
  );
  @override
  late final GeneratedColumn<String> containerExt = GeneratedColumn<String>(
    'container_ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directSourceMeta = const VerificationMeta(
    'directSource',
  );
  @override
  late final GeneratedColumn<String> directSource = GeneratedColumn<String>(
    'direct_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headersJsonMeta = const VerificationMeta(
    'headersJson',
  );
  @override
  late final GeneratedColumn<String> headersJson = GeneratedColumn<String>(
    'headers_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _removedMeta = const VerificationMeta(
    'removed',
  );
  @override
  late final GeneratedColumn<bool> removed = GeneratedColumn<bool>(
    'removed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("removed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _infoJsonMeta = const VerificationMeta(
    'infoJson',
  );
  @override
  late final GeneratedColumn<String> infoJson = GeneratedColumn<String>(
    'info_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _infoFetchedAtMeta = const VerificationMeta(
    'infoFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> infoFetchedAt =
      GeneratedColumn<DateTime>(
        'info_fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    providerId,
    name,
    categoryId,
    poster,
    rating,
    added,
    containerExt,
    tmdbId,
    year,
    streamUrl,
    directSource,
    headersJson,
    sortIndex,
    hidden,
    removed,
    infoJson,
    infoFetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movies';
  @override
  VerificationContext validateIntegrity(
    Insertable<MovieRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('poster')) {
      context.handle(
        _posterMeta,
        poster.isAcceptableOrUnknown(data['poster']!, _posterMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('added')) {
      context.handle(
        _addedMeta,
        added.isAcceptableOrUnknown(data['added']!, _addedMeta),
      );
    }
    if (data.containsKey('container_ext')) {
      context.handle(
        _containerExtMeta,
        containerExt.isAcceptableOrUnknown(
          data['container_ext']!,
          _containerExtMeta,
        ),
      );
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    }
    if (data.containsKey('direct_source')) {
      context.handle(
        _directSourceMeta,
        directSource.isAcceptableOrUnknown(
          data['direct_source']!,
          _directSourceMeta,
        ),
      );
    }
    if (data.containsKey('headers_json')) {
      context.handle(
        _headersJsonMeta,
        headersJson.isAcceptableOrUnknown(
          data['headers_json']!,
          _headersJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('removed')) {
      context.handle(
        _removedMeta,
        removed.isAcceptableOrUnknown(data['removed']!, _removedMeta),
      );
    }
    if (data.containsKey('info_json')) {
      context.handle(
        _infoJsonMeta,
        infoJson.isAcceptableOrUnknown(data['info_json']!, _infoJsonMeta),
      );
    }
    if (data.containsKey('info_fetched_at')) {
      context.handle(
        _infoFetchedAtMeta,
        infoFetchedAt.isAcceptableOrUnknown(
          data['info_fetched_at']!,
          _infoFetchedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, providerId},
  ];
  @override
  MovieRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MovieRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      poster: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      added: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added'],
      ),
      containerExt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container_ext'],
      ),
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_id'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      ),
      directSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direct_source'],
      ),
      headersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headers_json'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      removed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}removed'],
      )!,
      infoJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info_json'],
      ),
      infoFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}info_fetched_at'],
      ),
    );
  }

  @override
  $MoviesTable createAlias(String alias) {
    return $MoviesTable(attachedDatabase, alias);
  }
}

class MovieRow extends DataClass implements Insertable<MovieRow> {
  final int id;
  final int playlistId;
  final String providerId;
  final String name;
  final String? categoryId;
  final String? poster;

  /// Provider rating on a 0–10 scale.
  final double? rating;
  final DateTime? added;
  final String? containerExt;
  final int? tmdbId;
  final int? year;
  final String? streamUrl;
  final String? directSource;
  final String? headersJson;
  final int sortIndex;
  final bool hidden;
  final bool removed;

  /// Cached `get_vod_info` response (lazy, on detail open).
  final String? infoJson;
  final DateTime? infoFetchedAt;
  const MovieRow({
    required this.id,
    required this.playlistId,
    required this.providerId,
    required this.name,
    this.categoryId,
    this.poster,
    this.rating,
    this.added,
    this.containerExt,
    this.tmdbId,
    this.year,
    this.streamUrl,
    this.directSource,
    this.headersJson,
    required this.sortIndex,
    required this.hidden,
    required this.removed,
    this.infoJson,
    this.infoFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['provider_id'] = Variable<String>(providerId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || poster != null) {
      map['poster'] = Variable<String>(poster);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || added != null) {
      map['added'] = Variable<DateTime>(added);
    }
    if (!nullToAbsent || containerExt != null) {
      map['container_ext'] = Variable<String>(containerExt);
    }
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || streamUrl != null) {
      map['stream_url'] = Variable<String>(streamUrl);
    }
    if (!nullToAbsent || directSource != null) {
      map['direct_source'] = Variable<String>(directSource);
    }
    if (!nullToAbsent || headersJson != null) {
      map['headers_json'] = Variable<String>(headersJson);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['hidden'] = Variable<bool>(hidden);
    map['removed'] = Variable<bool>(removed);
    if (!nullToAbsent || infoJson != null) {
      map['info_json'] = Variable<String>(infoJson);
    }
    if (!nullToAbsent || infoFetchedAt != null) {
      map['info_fetched_at'] = Variable<DateTime>(infoFetchedAt);
    }
    return map;
  }

  MoviesCompanion toCompanion(bool nullToAbsent) {
    return MoviesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      providerId: Value(providerId),
      name: Value(name),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      poster: poster == null && nullToAbsent
          ? const Value.absent()
          : Value(poster),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      added: added == null && nullToAbsent
          ? const Value.absent()
          : Value(added),
      containerExt: containerExt == null && nullToAbsent
          ? const Value.absent()
          : Value(containerExt),
      tmdbId: tmdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbId),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      streamUrl: streamUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(streamUrl),
      directSource: directSource == null && nullToAbsent
          ? const Value.absent()
          : Value(directSource),
      headersJson: headersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(headersJson),
      sortIndex: Value(sortIndex),
      hidden: Value(hidden),
      removed: Value(removed),
      infoJson: infoJson == null && nullToAbsent
          ? const Value.absent()
          : Value(infoJson),
      infoFetchedAt: infoFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(infoFetchedAt),
    );
  }

  factory MovieRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MovieRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      poster: serializer.fromJson<String?>(json['poster']),
      rating: serializer.fromJson<double?>(json['rating']),
      added: serializer.fromJson<DateTime?>(json['added']),
      containerExt: serializer.fromJson<String?>(json['containerExt']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
      year: serializer.fromJson<int?>(json['year']),
      streamUrl: serializer.fromJson<String?>(json['streamUrl']),
      directSource: serializer.fromJson<String?>(json['directSource']),
      headersJson: serializer.fromJson<String?>(json['headersJson']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      removed: serializer.fromJson<bool>(json['removed']),
      infoJson: serializer.fromJson<String?>(json['infoJson']),
      infoFetchedAt: serializer.fromJson<DateTime?>(json['infoFetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'providerId': serializer.toJson<String>(providerId),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<String?>(categoryId),
      'poster': serializer.toJson<String?>(poster),
      'rating': serializer.toJson<double?>(rating),
      'added': serializer.toJson<DateTime?>(added),
      'containerExt': serializer.toJson<String?>(containerExt),
      'tmdbId': serializer.toJson<int?>(tmdbId),
      'year': serializer.toJson<int?>(year),
      'streamUrl': serializer.toJson<String?>(streamUrl),
      'directSource': serializer.toJson<String?>(directSource),
      'headersJson': serializer.toJson<String?>(headersJson),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'hidden': serializer.toJson<bool>(hidden),
      'removed': serializer.toJson<bool>(removed),
      'infoJson': serializer.toJson<String?>(infoJson),
      'infoFetchedAt': serializer.toJson<DateTime?>(infoFetchedAt),
    };
  }

  MovieRow copyWith({
    int? id,
    int? playlistId,
    String? providerId,
    String? name,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> poster = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<DateTime?> added = const Value.absent(),
    Value<String?> containerExt = const Value.absent(),
    Value<int?> tmdbId = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> streamUrl = const Value.absent(),
    Value<String?> directSource = const Value.absent(),
    Value<String?> headersJson = const Value.absent(),
    int? sortIndex,
    bool? hidden,
    bool? removed,
    Value<String?> infoJson = const Value.absent(),
    Value<DateTime?> infoFetchedAt = const Value.absent(),
  }) => MovieRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    providerId: providerId ?? this.providerId,
    name: name ?? this.name,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    poster: poster.present ? poster.value : this.poster,
    rating: rating.present ? rating.value : this.rating,
    added: added.present ? added.value : this.added,
    containerExt: containerExt.present ? containerExt.value : this.containerExt,
    tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
    year: year.present ? year.value : this.year,
    streamUrl: streamUrl.present ? streamUrl.value : this.streamUrl,
    directSource: directSource.present ? directSource.value : this.directSource,
    headersJson: headersJson.present ? headersJson.value : this.headersJson,
    sortIndex: sortIndex ?? this.sortIndex,
    hidden: hidden ?? this.hidden,
    removed: removed ?? this.removed,
    infoJson: infoJson.present ? infoJson.value : this.infoJson,
    infoFetchedAt: infoFetchedAt.present
        ? infoFetchedAt.value
        : this.infoFetchedAt,
  );
  MovieRow copyWithCompanion(MoviesCompanion data) {
    return MovieRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      poster: data.poster.present ? data.poster.value : this.poster,
      rating: data.rating.present ? data.rating.value : this.rating,
      added: data.added.present ? data.added.value : this.added,
      containerExt: data.containerExt.present
          ? data.containerExt.value
          : this.containerExt,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      year: data.year.present ? data.year.value : this.year,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      directSource: data.directSource.present
          ? data.directSource.value
          : this.directSource,
      headersJson: data.headersJson.present
          ? data.headersJson.value
          : this.headersJson,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      removed: data.removed.present ? data.removed.value : this.removed,
      infoJson: data.infoJson.present ? data.infoJson.value : this.infoJson,
      infoFetchedAt: data.infoFetchedAt.present
          ? data.infoFetchedAt.value
          : this.infoFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MovieRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('poster: $poster, ')
          ..write('rating: $rating, ')
          ..write('added: $added, ')
          ..write('containerExt: $containerExt, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('year: $year, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('directSource: $directSource, ')
          ..write('headersJson: $headersJson, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('hidden: $hidden, ')
          ..write('removed: $removed, ')
          ..write('infoJson: $infoJson, ')
          ..write('infoFetchedAt: $infoFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    providerId,
    name,
    categoryId,
    poster,
    rating,
    added,
    containerExt,
    tmdbId,
    year,
    streamUrl,
    directSource,
    headersJson,
    sortIndex,
    hidden,
    removed,
    infoJson,
    infoFetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovieRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.providerId == this.providerId &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.poster == this.poster &&
          other.rating == this.rating &&
          other.added == this.added &&
          other.containerExt == this.containerExt &&
          other.tmdbId == this.tmdbId &&
          other.year == this.year &&
          other.streamUrl == this.streamUrl &&
          other.directSource == this.directSource &&
          other.headersJson == this.headersJson &&
          other.sortIndex == this.sortIndex &&
          other.hidden == this.hidden &&
          other.removed == this.removed &&
          other.infoJson == this.infoJson &&
          other.infoFetchedAt == this.infoFetchedAt);
}

class MoviesCompanion extends UpdateCompanion<MovieRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> providerId;
  final Value<String> name;
  final Value<String?> categoryId;
  final Value<String?> poster;
  final Value<double?> rating;
  final Value<DateTime?> added;
  final Value<String?> containerExt;
  final Value<int?> tmdbId;
  final Value<int?> year;
  final Value<String?> streamUrl;
  final Value<String?> directSource;
  final Value<String?> headersJson;
  final Value<int> sortIndex;
  final Value<bool> hidden;
  final Value<bool> removed;
  final Value<String?> infoJson;
  final Value<DateTime?> infoFetchedAt;
  const MoviesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.poster = const Value.absent(),
    this.rating = const Value.absent(),
    this.added = const Value.absent(),
    this.containerExt = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.year = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.directSource = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.hidden = const Value.absent(),
    this.removed = const Value.absent(),
    this.infoJson = const Value.absent(),
    this.infoFetchedAt = const Value.absent(),
  });
  MoviesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String providerId,
    required String name,
    this.categoryId = const Value.absent(),
    this.poster = const Value.absent(),
    this.rating = const Value.absent(),
    this.added = const Value.absent(),
    this.containerExt = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.year = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.directSource = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.hidden = const Value.absent(),
    this.removed = const Value.absent(),
    this.infoJson = const Value.absent(),
    this.infoFetchedAt = const Value.absent(),
  }) : playlistId = Value(playlistId),
       providerId = Value(providerId),
       name = Value(name);
  static Insertable<MovieRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? providerId,
    Expression<String>? name,
    Expression<String>? categoryId,
    Expression<String>? poster,
    Expression<double>? rating,
    Expression<DateTime>? added,
    Expression<String>? containerExt,
    Expression<int>? tmdbId,
    Expression<int>? year,
    Expression<String>? streamUrl,
    Expression<String>? directSource,
    Expression<String>? headersJson,
    Expression<int>? sortIndex,
    Expression<bool>? hidden,
    Expression<bool>? removed,
    Expression<String>? infoJson,
    Expression<DateTime>? infoFetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (providerId != null) 'provider_id': providerId,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (poster != null) 'poster': poster,
      if (rating != null) 'rating': rating,
      if (added != null) 'added': added,
      if (containerExt != null) 'container_ext': containerExt,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (year != null) 'year': year,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (directSource != null) 'direct_source': directSource,
      if (headersJson != null) 'headers_json': headersJson,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (hidden != null) 'hidden': hidden,
      if (removed != null) 'removed': removed,
      if (infoJson != null) 'info_json': infoJson,
      if (infoFetchedAt != null) 'info_fetched_at': infoFetchedAt,
    });
  }

  MoviesCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? providerId,
    Value<String>? name,
    Value<String?>? categoryId,
    Value<String?>? poster,
    Value<double?>? rating,
    Value<DateTime?>? added,
    Value<String?>? containerExt,
    Value<int?>? tmdbId,
    Value<int?>? year,
    Value<String?>? streamUrl,
    Value<String?>? directSource,
    Value<String?>? headersJson,
    Value<int>? sortIndex,
    Value<bool>? hidden,
    Value<bool>? removed,
    Value<String?>? infoJson,
    Value<DateTime?>? infoFetchedAt,
  }) {
    return MoviesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      poster: poster ?? this.poster,
      rating: rating ?? this.rating,
      added: added ?? this.added,
      containerExt: containerExt ?? this.containerExt,
      tmdbId: tmdbId ?? this.tmdbId,
      year: year ?? this.year,
      streamUrl: streamUrl ?? this.streamUrl,
      directSource: directSource ?? this.directSource,
      headersJson: headersJson ?? this.headersJson,
      sortIndex: sortIndex ?? this.sortIndex,
      hidden: hidden ?? this.hidden,
      removed: removed ?? this.removed,
      infoJson: infoJson ?? this.infoJson,
      infoFetchedAt: infoFetchedAt ?? this.infoFetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (poster.present) {
      map['poster'] = Variable<String>(poster.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (added.present) {
      map['added'] = Variable<DateTime>(added.value);
    }
    if (containerExt.present) {
      map['container_ext'] = Variable<String>(containerExt.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (directSource.present) {
      map['direct_source'] = Variable<String>(directSource.value);
    }
    if (headersJson.present) {
      map['headers_json'] = Variable<String>(headersJson.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (removed.present) {
      map['removed'] = Variable<bool>(removed.value);
    }
    if (infoJson.present) {
      map['info_json'] = Variable<String>(infoJson.value);
    }
    if (infoFetchedAt.present) {
      map['info_fetched_at'] = Variable<DateTime>(infoFetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoviesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('poster: $poster, ')
          ..write('rating: $rating, ')
          ..write('added: $added, ')
          ..write('containerExt: $containerExt, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('year: $year, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('directSource: $directSource, ')
          ..write('headersJson: $headersJson, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('hidden: $hidden, ')
          ..write('removed: $removed, ')
          ..write('infoJson: $infoJson, ')
          ..write('infoFetchedAt: $infoFetchedAt')
          ..write(')'))
        .toString();
  }
}

class $SeriesTable extends Series with TableInfo<$SeriesTable, SeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _castMeta = const VerificationMeta('cast');
  @override
  late final GeneratedColumn<String> cast = GeneratedColumn<String>(
    'cast',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directorMeta = const VerificationMeta(
    'director',
  );
  @override
  late final GeneratedColumn<String> director = GeneratedColumn<String>(
    'director',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<String> releaseDate = GeneratedColumn<String>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
    'last_modified',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropsJsonMeta = const VerificationMeta(
    'backdropsJson',
  );
  @override
  late final GeneratedColumn<String> backdropsJson = GeneratedColumn<String>(
    'backdrops_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _youtubeTrailerMeta = const VerificationMeta(
    'youtubeTrailer',
  );
  @override
  late final GeneratedColumn<String> youtubeTrailer = GeneratedColumn<String>(
    'youtube_trailer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _removedMeta = const VerificationMeta(
    'removed',
  );
  @override
  late final GeneratedColumn<bool> removed = GeneratedColumn<bool>(
    'removed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("removed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _infoJsonMeta = const VerificationMeta(
    'infoJson',
  );
  @override
  late final GeneratedColumn<String> infoJson = GeneratedColumn<String>(
    'info_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _infoFetchedAtMeta = const VerificationMeta(
    'infoFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> infoFetchedAt =
      GeneratedColumn<DateTime>(
        'info_fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    providerId,
    name,
    categoryId,
    cover,
    plot,
    cast,
    director,
    genre,
    releaseDate,
    lastModified,
    rating,
    backdropsJson,
    youtubeTrailer,
    tmdbId,
    year,
    sortIndex,
    hidden,
    removed,
    infoJson,
    infoFetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('cast')) {
      context.handle(
        _castMeta,
        cast.isAcceptableOrUnknown(data['cast']!, _castMeta),
      );
    }
    if (data.containsKey('director')) {
      context.handle(
        _directorMeta,
        director.isAcceptableOrUnknown(data['director']!, _directorMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('backdrops_json')) {
      context.handle(
        _backdropsJsonMeta,
        backdropsJson.isAcceptableOrUnknown(
          data['backdrops_json']!,
          _backdropsJsonMeta,
        ),
      );
    }
    if (data.containsKey('youtube_trailer')) {
      context.handle(
        _youtubeTrailerMeta,
        youtubeTrailer.isAcceptableOrUnknown(
          data['youtube_trailer']!,
          _youtubeTrailerMeta,
        ),
      );
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('removed')) {
      context.handle(
        _removedMeta,
        removed.isAcceptableOrUnknown(data['removed']!, _removedMeta),
      );
    }
    if (data.containsKey('info_json')) {
      context.handle(
        _infoJsonMeta,
        infoJson.isAcceptableOrUnknown(data['info_json']!, _infoJsonMeta),
      );
    }
    if (data.containsKey('info_fetched_at')) {
      context.handle(
        _infoFetchedAtMeta,
        infoFetchedAt.isAcceptableOrUnknown(
          data['info_fetched_at']!,
          _infoFetchedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, providerId},
  ];
  @override
  SeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      cast: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast'],
      ),
      director: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}director'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}release_date'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      backdropsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrops_json'],
      ),
      youtubeTrailer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}youtube_trailer'],
      ),
      tmdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_id'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      removed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}removed'],
      )!,
      infoJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info_json'],
      ),
      infoFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}info_fetched_at'],
      ),
    );
  }

  @override
  $SeriesTable createAlias(String alias) {
    return $SeriesTable(attachedDatabase, alias);
  }
}

class SeriesRow extends DataClass implements Insertable<SeriesRow> {
  final int id;
  final int playlistId;
  final String providerId;
  final String name;
  final String? categoryId;
  final String? cover;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final DateTime? lastModified;
  final double? rating;

  /// JSON list of backdrop URLs.
  final String? backdropsJson;
  final String? youtubeTrailer;
  final int? tmdbId;
  final int? year;
  final int sortIndex;
  final bool hidden;
  final bool removed;

  /// Raw `get_series_info.info` JSON (lazy).
  final String? infoJson;
  final DateTime? infoFetchedAt;
  const SeriesRow({
    required this.id,
    required this.playlistId,
    required this.providerId,
    required this.name,
    this.categoryId,
    this.cover,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.lastModified,
    this.rating,
    this.backdropsJson,
    this.youtubeTrailer,
    this.tmdbId,
    this.year,
    required this.sortIndex,
    required this.hidden,
    required this.removed,
    this.infoJson,
    this.infoFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['provider_id'] = Variable<String>(providerId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || cast != null) {
      map['cast'] = Variable<String>(cast);
    }
    if (!nullToAbsent || director != null) {
      map['director'] = Variable<String>(director);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<String>(releaseDate);
    }
    if (!nullToAbsent || lastModified != null) {
      map['last_modified'] = Variable<DateTime>(lastModified);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || backdropsJson != null) {
      map['backdrops_json'] = Variable<String>(backdropsJson);
    }
    if (!nullToAbsent || youtubeTrailer != null) {
      map['youtube_trailer'] = Variable<String>(youtubeTrailer);
    }
    if (!nullToAbsent || tmdbId != null) {
      map['tmdb_id'] = Variable<int>(tmdbId);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['hidden'] = Variable<bool>(hidden);
    map['removed'] = Variable<bool>(removed);
    if (!nullToAbsent || infoJson != null) {
      map['info_json'] = Variable<String>(infoJson);
    }
    if (!nullToAbsent || infoFetchedAt != null) {
      map['info_fetched_at'] = Variable<DateTime>(infoFetchedAt);
    }
    return map;
  }

  SeriesCompanion toCompanion(bool nullToAbsent) {
    return SeriesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      providerId: Value(providerId),
      name: Value(name),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      cast: cast == null && nullToAbsent ? const Value.absent() : Value(cast),
      director: director == null && nullToAbsent
          ? const Value.absent()
          : Value(director),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      releaseDate: releaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseDate),
      lastModified: lastModified == null && nullToAbsent
          ? const Value.absent()
          : Value(lastModified),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      backdropsJson: backdropsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropsJson),
      youtubeTrailer: youtubeTrailer == null && nullToAbsent
          ? const Value.absent()
          : Value(youtubeTrailer),
      tmdbId: tmdbId == null && nullToAbsent
          ? const Value.absent()
          : Value(tmdbId),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      sortIndex: Value(sortIndex),
      hidden: Value(hidden),
      removed: Value(removed),
      infoJson: infoJson == null && nullToAbsent
          ? const Value.absent()
          : Value(infoJson),
      infoFetchedAt: infoFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(infoFetchedAt),
    );
  }

  factory SeriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      cover: serializer.fromJson<String?>(json['cover']),
      plot: serializer.fromJson<String?>(json['plot']),
      cast: serializer.fromJson<String?>(json['cast']),
      director: serializer.fromJson<String?>(json['director']),
      genre: serializer.fromJson<String?>(json['genre']),
      releaseDate: serializer.fromJson<String?>(json['releaseDate']),
      lastModified: serializer.fromJson<DateTime?>(json['lastModified']),
      rating: serializer.fromJson<double?>(json['rating']),
      backdropsJson: serializer.fromJson<String?>(json['backdropsJson']),
      youtubeTrailer: serializer.fromJson<String?>(json['youtubeTrailer']),
      tmdbId: serializer.fromJson<int?>(json['tmdbId']),
      year: serializer.fromJson<int?>(json['year']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      removed: serializer.fromJson<bool>(json['removed']),
      infoJson: serializer.fromJson<String?>(json['infoJson']),
      infoFetchedAt: serializer.fromJson<DateTime?>(json['infoFetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'providerId': serializer.toJson<String>(providerId),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<String?>(categoryId),
      'cover': serializer.toJson<String?>(cover),
      'plot': serializer.toJson<String?>(plot),
      'cast': serializer.toJson<String?>(cast),
      'director': serializer.toJson<String?>(director),
      'genre': serializer.toJson<String?>(genre),
      'releaseDate': serializer.toJson<String?>(releaseDate),
      'lastModified': serializer.toJson<DateTime?>(lastModified),
      'rating': serializer.toJson<double?>(rating),
      'backdropsJson': serializer.toJson<String?>(backdropsJson),
      'youtubeTrailer': serializer.toJson<String?>(youtubeTrailer),
      'tmdbId': serializer.toJson<int?>(tmdbId),
      'year': serializer.toJson<int?>(year),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'hidden': serializer.toJson<bool>(hidden),
      'removed': serializer.toJson<bool>(removed),
      'infoJson': serializer.toJson<String?>(infoJson),
      'infoFetchedAt': serializer.toJson<DateTime?>(infoFetchedAt),
    };
  }

  SeriesRow copyWith({
    int? id,
    int? playlistId,
    String? providerId,
    String? name,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> cover = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<String?> cast = const Value.absent(),
    Value<String?> director = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<String?> releaseDate = const Value.absent(),
    Value<DateTime?> lastModified = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<String?> backdropsJson = const Value.absent(),
    Value<String?> youtubeTrailer = const Value.absent(),
    Value<int?> tmdbId = const Value.absent(),
    Value<int?> year = const Value.absent(),
    int? sortIndex,
    bool? hidden,
    bool? removed,
    Value<String?> infoJson = const Value.absent(),
    Value<DateTime?> infoFetchedAt = const Value.absent(),
  }) => SeriesRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    providerId: providerId ?? this.providerId,
    name: name ?? this.name,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    cover: cover.present ? cover.value : this.cover,
    plot: plot.present ? plot.value : this.plot,
    cast: cast.present ? cast.value : this.cast,
    director: director.present ? director.value : this.director,
    genre: genre.present ? genre.value : this.genre,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    lastModified: lastModified.present ? lastModified.value : this.lastModified,
    rating: rating.present ? rating.value : this.rating,
    backdropsJson: backdropsJson.present
        ? backdropsJson.value
        : this.backdropsJson,
    youtubeTrailer: youtubeTrailer.present
        ? youtubeTrailer.value
        : this.youtubeTrailer,
    tmdbId: tmdbId.present ? tmdbId.value : this.tmdbId,
    year: year.present ? year.value : this.year,
    sortIndex: sortIndex ?? this.sortIndex,
    hidden: hidden ?? this.hidden,
    removed: removed ?? this.removed,
    infoJson: infoJson.present ? infoJson.value : this.infoJson,
    infoFetchedAt: infoFetchedAt.present
        ? infoFetchedAt.value
        : this.infoFetchedAt,
  );
  SeriesRow copyWithCompanion(SeriesCompanion data) {
    return SeriesRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      cover: data.cover.present ? data.cover.value : this.cover,
      plot: data.plot.present ? data.plot.value : this.plot,
      cast: data.cast.present ? data.cast.value : this.cast,
      director: data.director.present ? data.director.value : this.director,
      genre: data.genre.present ? data.genre.value : this.genre,
      releaseDate: data.releaseDate.present
          ? data.releaseDate.value
          : this.releaseDate,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      rating: data.rating.present ? data.rating.value : this.rating,
      backdropsJson: data.backdropsJson.present
          ? data.backdropsJson.value
          : this.backdropsJson,
      youtubeTrailer: data.youtubeTrailer.present
          ? data.youtubeTrailer.value
          : this.youtubeTrailer,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      year: data.year.present ? data.year.value : this.year,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      removed: data.removed.present ? data.removed.value : this.removed,
      infoJson: data.infoJson.present ? data.infoJson.value : this.infoJson,
      infoFetchedAt: data.infoFetchedAt.present
          ? data.infoFetchedAt.value
          : this.infoFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('cover: $cover, ')
          ..write('plot: $plot, ')
          ..write('cast: $cast, ')
          ..write('director: $director, ')
          ..write('genre: $genre, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('lastModified: $lastModified, ')
          ..write('rating: $rating, ')
          ..write('backdropsJson: $backdropsJson, ')
          ..write('youtubeTrailer: $youtubeTrailer, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('year: $year, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('hidden: $hidden, ')
          ..write('removed: $removed, ')
          ..write('infoJson: $infoJson, ')
          ..write('infoFetchedAt: $infoFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    playlistId,
    providerId,
    name,
    categoryId,
    cover,
    plot,
    cast,
    director,
    genre,
    releaseDate,
    lastModified,
    rating,
    backdropsJson,
    youtubeTrailer,
    tmdbId,
    year,
    sortIndex,
    hidden,
    removed,
    infoJson,
    infoFetchedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.providerId == this.providerId &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.cover == this.cover &&
          other.plot == this.plot &&
          other.cast == this.cast &&
          other.director == this.director &&
          other.genre == this.genre &&
          other.releaseDate == this.releaseDate &&
          other.lastModified == this.lastModified &&
          other.rating == this.rating &&
          other.backdropsJson == this.backdropsJson &&
          other.youtubeTrailer == this.youtubeTrailer &&
          other.tmdbId == this.tmdbId &&
          other.year == this.year &&
          other.sortIndex == this.sortIndex &&
          other.hidden == this.hidden &&
          other.removed == this.removed &&
          other.infoJson == this.infoJson &&
          other.infoFetchedAt == this.infoFetchedAt);
}

class SeriesCompanion extends UpdateCompanion<SeriesRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> providerId;
  final Value<String> name;
  final Value<String?> categoryId;
  final Value<String?> cover;
  final Value<String?> plot;
  final Value<String?> cast;
  final Value<String?> director;
  final Value<String?> genre;
  final Value<String?> releaseDate;
  final Value<DateTime?> lastModified;
  final Value<double?> rating;
  final Value<String?> backdropsJson;
  final Value<String?> youtubeTrailer;
  final Value<int?> tmdbId;
  final Value<int?> year;
  final Value<int> sortIndex;
  final Value<bool> hidden;
  final Value<bool> removed;
  final Value<String?> infoJson;
  final Value<DateTime?> infoFetchedAt;
  const SeriesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.cover = const Value.absent(),
    this.plot = const Value.absent(),
    this.cast = const Value.absent(),
    this.director = const Value.absent(),
    this.genre = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.rating = const Value.absent(),
    this.backdropsJson = const Value.absent(),
    this.youtubeTrailer = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.year = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.hidden = const Value.absent(),
    this.removed = const Value.absent(),
    this.infoJson = const Value.absent(),
    this.infoFetchedAt = const Value.absent(),
  });
  SeriesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String providerId,
    required String name,
    this.categoryId = const Value.absent(),
    this.cover = const Value.absent(),
    this.plot = const Value.absent(),
    this.cast = const Value.absent(),
    this.director = const Value.absent(),
    this.genre = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.rating = const Value.absent(),
    this.backdropsJson = const Value.absent(),
    this.youtubeTrailer = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.year = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.hidden = const Value.absent(),
    this.removed = const Value.absent(),
    this.infoJson = const Value.absent(),
    this.infoFetchedAt = const Value.absent(),
  }) : playlistId = Value(playlistId),
       providerId = Value(providerId),
       name = Value(name);
  static Insertable<SeriesRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? providerId,
    Expression<String>? name,
    Expression<String>? categoryId,
    Expression<String>? cover,
    Expression<String>? plot,
    Expression<String>? cast,
    Expression<String>? director,
    Expression<String>? genre,
    Expression<String>? releaseDate,
    Expression<DateTime>? lastModified,
    Expression<double>? rating,
    Expression<String>? backdropsJson,
    Expression<String>? youtubeTrailer,
    Expression<int>? tmdbId,
    Expression<int>? year,
    Expression<int>? sortIndex,
    Expression<bool>? hidden,
    Expression<bool>? removed,
    Expression<String>? infoJson,
    Expression<DateTime>? infoFetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (providerId != null) 'provider_id': providerId,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (cover != null) 'cover': cover,
      if (plot != null) 'plot': plot,
      if (cast != null) 'cast': cast,
      if (director != null) 'director': director,
      if (genre != null) 'genre': genre,
      if (releaseDate != null) 'release_date': releaseDate,
      if (lastModified != null) 'last_modified': lastModified,
      if (rating != null) 'rating': rating,
      if (backdropsJson != null) 'backdrops_json': backdropsJson,
      if (youtubeTrailer != null) 'youtube_trailer': youtubeTrailer,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (year != null) 'year': year,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (hidden != null) 'hidden': hidden,
      if (removed != null) 'removed': removed,
      if (infoJson != null) 'info_json': infoJson,
      if (infoFetchedAt != null) 'info_fetched_at': infoFetchedAt,
    });
  }

  SeriesCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? providerId,
    Value<String>? name,
    Value<String?>? categoryId,
    Value<String?>? cover,
    Value<String?>? plot,
    Value<String?>? cast,
    Value<String?>? director,
    Value<String?>? genre,
    Value<String?>? releaseDate,
    Value<DateTime?>? lastModified,
    Value<double?>? rating,
    Value<String?>? backdropsJson,
    Value<String?>? youtubeTrailer,
    Value<int?>? tmdbId,
    Value<int?>? year,
    Value<int>? sortIndex,
    Value<bool>? hidden,
    Value<bool>? removed,
    Value<String?>? infoJson,
    Value<DateTime?>? infoFetchedAt,
  }) {
    return SeriesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      cover: cover ?? this.cover,
      plot: plot ?? this.plot,
      cast: cast ?? this.cast,
      director: director ?? this.director,
      genre: genre ?? this.genre,
      releaseDate: releaseDate ?? this.releaseDate,
      lastModified: lastModified ?? this.lastModified,
      rating: rating ?? this.rating,
      backdropsJson: backdropsJson ?? this.backdropsJson,
      youtubeTrailer: youtubeTrailer ?? this.youtubeTrailer,
      tmdbId: tmdbId ?? this.tmdbId,
      year: year ?? this.year,
      sortIndex: sortIndex ?? this.sortIndex,
      hidden: hidden ?? this.hidden,
      removed: removed ?? this.removed,
      infoJson: infoJson ?? this.infoJson,
      infoFetchedAt: infoFetchedAt ?? this.infoFetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (cast.present) {
      map['cast'] = Variable<String>(cast.value);
    }
    if (director.present) {
      map['director'] = Variable<String>(director.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<String>(releaseDate.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (backdropsJson.present) {
      map['backdrops_json'] = Variable<String>(backdropsJson.value);
    }
    if (youtubeTrailer.present) {
      map['youtube_trailer'] = Variable<String>(youtubeTrailer.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (removed.present) {
      map['removed'] = Variable<bool>(removed.value);
    }
    if (infoJson.present) {
      map['info_json'] = Variable<String>(infoJson.value);
    }
    if (infoFetchedAt.present) {
      map['info_fetched_at'] = Variable<DateTime>(infoFetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('providerId: $providerId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('cover: $cover, ')
          ..write('plot: $plot, ')
          ..write('cast: $cast, ')
          ..write('director: $director, ')
          ..write('genre: $genre, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('lastModified: $lastModified, ')
          ..write('rating: $rating, ')
          ..write('backdropsJson: $backdropsJson, ')
          ..write('youtubeTrailer: $youtubeTrailer, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('year: $year, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('hidden: $hidden, ')
          ..write('removed: $removed, ')
          ..write('infoJson: $infoJson, ')
          ..write('infoFetchedAt: $infoFetchedAt')
          ..write(')'))
        .toString();
  }
}

class $SeasonsTable extends Seasons with TableInfo<$SeasonsTable, SeasonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeasonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seasonNumberMeta = const VerificationMeta(
    'seasonNumber',
  );
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
    'season_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airDateMeta = const VerificationMeta(
    'airDate',
  );
  @override
  late final GeneratedColumn<String> airDate = GeneratedColumn<String>(
    'air_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeCountMeta = const VerificationMeta(
    'episodeCount',
  );
  @override
  late final GeneratedColumn<int> episodeCount = GeneratedColumn<int>(
    'episode_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _overviewMeta = const VerificationMeta(
    'overview',
  );
  @override
  late final GeneratedColumn<String> overview = GeneratedColumn<String>(
    'overview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    seriesId,
    seasonNumber,
    name,
    cover,
    airDate,
    episodeCount,
    overview,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seasons';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeasonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('season_number')) {
      context.handle(
        _seasonNumberMeta,
        seasonNumber.isAcceptableOrUnknown(
          data['season_number']!,
          _seasonNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seasonNumberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('air_date')) {
      context.handle(
        _airDateMeta,
        airDate.isAcceptableOrUnknown(data['air_date']!, _airDateMeta),
      );
    }
    if (data.containsKey('episode_count')) {
      context.handle(
        _episodeCountMeta,
        episodeCount.isAcceptableOrUnknown(
          data['episode_count']!,
          _episodeCountMeta,
        ),
      );
    }
    if (data.containsKey('overview')) {
      context.handle(
        _overviewMeta,
        overview.isAcceptableOrUnknown(data['overview']!, _overviewMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, seriesId, seasonNumber},
  ];
  @override
  SeasonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeasonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
      seasonNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season_number'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      airDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}air_date'],
      ),
      episodeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_count'],
      ),
      overview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overview'],
      ),
    );
  }

  @override
  $SeasonsTable createAlias(String alias) {
    return $SeasonsTable(attachedDatabase, alias);
  }
}

class SeasonRow extends DataClass implements Insertable<SeasonRow> {
  final int id;
  final int playlistId;

  /// Provider series id.
  final String seriesId;
  final int seasonNumber;
  final String? name;
  final String? cover;
  final String? airDate;
  final int? episodeCount;
  final String? overview;
  const SeasonRow({
    required this.id,
    required this.playlistId,
    required this.seriesId,
    required this.seasonNumber,
    this.name,
    this.cover,
    this.airDate,
    this.episodeCount,
    this.overview,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['series_id'] = Variable<String>(seriesId);
    map['season_number'] = Variable<int>(seasonNumber);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    if (!nullToAbsent || airDate != null) {
      map['air_date'] = Variable<String>(airDate);
    }
    if (!nullToAbsent || episodeCount != null) {
      map['episode_count'] = Variable<int>(episodeCount);
    }
    if (!nullToAbsent || overview != null) {
      map['overview'] = Variable<String>(overview);
    }
    return map;
  }

  SeasonsCompanion toCompanion(bool nullToAbsent) {
    return SeasonsCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      seriesId: Value(seriesId),
      seasonNumber: Value(seasonNumber),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      airDate: airDate == null && nullToAbsent
          ? const Value.absent()
          : Value(airDate),
      episodeCount: episodeCount == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeCount),
      overview: overview == null && nullToAbsent
          ? const Value.absent()
          : Value(overview),
    );
  }

  factory SeasonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeasonRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      seasonNumber: serializer.fromJson<int>(json['seasonNumber']),
      name: serializer.fromJson<String?>(json['name']),
      cover: serializer.fromJson<String?>(json['cover']),
      airDate: serializer.fromJson<String?>(json['airDate']),
      episodeCount: serializer.fromJson<int?>(json['episodeCount']),
      overview: serializer.fromJson<String?>(json['overview']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'seriesId': serializer.toJson<String>(seriesId),
      'seasonNumber': serializer.toJson<int>(seasonNumber),
      'name': serializer.toJson<String?>(name),
      'cover': serializer.toJson<String?>(cover),
      'airDate': serializer.toJson<String?>(airDate),
      'episodeCount': serializer.toJson<int?>(episodeCount),
      'overview': serializer.toJson<String?>(overview),
    };
  }

  SeasonRow copyWith({
    int? id,
    int? playlistId,
    String? seriesId,
    int? seasonNumber,
    Value<String?> name = const Value.absent(),
    Value<String?> cover = const Value.absent(),
    Value<String?> airDate = const Value.absent(),
    Value<int?> episodeCount = const Value.absent(),
    Value<String?> overview = const Value.absent(),
  }) => SeasonRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    seriesId: seriesId ?? this.seriesId,
    seasonNumber: seasonNumber ?? this.seasonNumber,
    name: name.present ? name.value : this.name,
    cover: cover.present ? cover.value : this.cover,
    airDate: airDate.present ? airDate.value : this.airDate,
    episodeCount: episodeCount.present ? episodeCount.value : this.episodeCount,
    overview: overview.present ? overview.value : this.overview,
  );
  SeasonRow copyWithCompanion(SeasonsCompanion data) {
    return SeasonRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      name: data.name.present ? data.name.value : this.name,
      cover: data.cover.present ? data.cover.value : this.cover,
      airDate: data.airDate.present ? data.airDate.value : this.airDate,
      episodeCount: data.episodeCount.present
          ? data.episodeCount.value
          : this.episodeCount,
      overview: data.overview.present ? data.overview.value : this.overview,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeasonRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('seriesId: $seriesId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('name: $name, ')
          ..write('cover: $cover, ')
          ..write('airDate: $airDate, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('overview: $overview')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    seriesId,
    seasonNumber,
    name,
    cover,
    airDate,
    episodeCount,
    overview,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeasonRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.seriesId == this.seriesId &&
          other.seasonNumber == this.seasonNumber &&
          other.name == this.name &&
          other.cover == this.cover &&
          other.airDate == this.airDate &&
          other.episodeCount == this.episodeCount &&
          other.overview == this.overview);
}

class SeasonsCompanion extends UpdateCompanion<SeasonRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> seriesId;
  final Value<int> seasonNumber;
  final Value<String?> name;
  final Value<String?> cover;
  final Value<String?> airDate;
  final Value<int?> episodeCount;
  final Value<String?> overview;
  const SeasonsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.name = const Value.absent(),
    this.cover = const Value.absent(),
    this.airDate = const Value.absent(),
    this.episodeCount = const Value.absent(),
    this.overview = const Value.absent(),
  });
  SeasonsCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String seriesId,
    required int seasonNumber,
    this.name = const Value.absent(),
    this.cover = const Value.absent(),
    this.airDate = const Value.absent(),
    this.episodeCount = const Value.absent(),
    this.overview = const Value.absent(),
  }) : playlistId = Value(playlistId),
       seriesId = Value(seriesId),
       seasonNumber = Value(seasonNumber);
  static Insertable<SeasonRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? seriesId,
    Expression<int>? seasonNumber,
    Expression<String>? name,
    Expression<String>? cover,
    Expression<String>? airDate,
    Expression<int>? episodeCount,
    Expression<String>? overview,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (seriesId != null) 'series_id': seriesId,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (name != null) 'name': name,
      if (cover != null) 'cover': cover,
      if (airDate != null) 'air_date': airDate,
      if (episodeCount != null) 'episode_count': episodeCount,
      if (overview != null) 'overview': overview,
    });
  }

  SeasonsCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? seriesId,
    Value<int>? seasonNumber,
    Value<String?>? name,
    Value<String?>? cover,
    Value<String?>? airDate,
    Value<int?>? episodeCount,
    Value<String?>? overview,
  }) {
    return SeasonsCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      seriesId: seriesId ?? this.seriesId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      name: name ?? this.name,
      cover: cover ?? this.cover,
      airDate: airDate ?? this.airDate,
      episodeCount: episodeCount ?? this.episodeCount,
      overview: overview ?? this.overview,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (airDate.present) {
      map['air_date'] = Variable<String>(airDate.value);
    }
    if (episodeCount.present) {
      map['episode_count'] = Variable<int>(episodeCount.value);
    }
    if (overview.present) {
      map['overview'] = Variable<String>(overview.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeasonsCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('seriesId: $seriesId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('name: $name, ')
          ..write('cover: $cover, ')
          ..write('airDate: $airDate, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('overview: $overview')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes
    with TableInfo<$EpisodesTable, EpisodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeNumMeta = const VerificationMeta(
    'episodeNum',
  );
  @override
  late final GeneratedColumn<int> episodeNum = GeneratedColumn<int>(
    'episode_num',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _containerExtMeta = const VerificationMeta(
    'containerExt',
  );
  @override
  late final GeneratedColumn<String> containerExt = GeneratedColumn<String>(
    'container_ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plotMeta = const VerificationMeta('plot');
  @override
  late final GeneratedColumn<String> plot = GeneratedColumn<String>(
    'plot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecsMeta = const VerificationMeta(
    'durationSecs',
  );
  @override
  late final GeneratedColumn<int> durationSecs = GeneratedColumn<int>(
    'duration_secs',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<String> releaseDate = GeneratedColumn<String>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<String> image = GeneratedColumn<String>(
    'image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directSourceMeta = const VerificationMeta(
    'directSource',
  );
  @override
  late final GeneratedColumn<String> directSource = GeneratedColumn<String>(
    'direct_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<DateTime> added = GeneratedColumn<DateTime>(
    'added',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    providerId,
    seriesId,
    season,
    episodeNum,
    title,
    containerExt,
    plot,
    durationSecs,
    releaseDate,
    image,
    rating,
    streamUrl,
    directSource,
    added,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesIdMeta);
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    } else if (isInserting) {
      context.missing(_seasonMeta);
    }
    if (data.containsKey('episode_num')) {
      context.handle(
        _episodeNumMeta,
        episodeNum.isAcceptableOrUnknown(data['episode_num']!, _episodeNumMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeNumMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('container_ext')) {
      context.handle(
        _containerExtMeta,
        containerExt.isAcceptableOrUnknown(
          data['container_ext']!,
          _containerExtMeta,
        ),
      );
    }
    if (data.containsKey('plot')) {
      context.handle(
        _plotMeta,
        plot.isAcceptableOrUnknown(data['plot']!, _plotMeta),
      );
    }
    if (data.containsKey('duration_secs')) {
      context.handle(
        _durationSecsMeta,
        durationSecs.isAcceptableOrUnknown(
          data['duration_secs']!,
          _durationSecsMeta,
        ),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('image')) {
      context.handle(
        _imageMeta,
        image.isAcceptableOrUnknown(data['image']!, _imageMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    }
    if (data.containsKey('direct_source')) {
      context.handle(
        _directSourceMeta,
        directSource.isAcceptableOrUnknown(
          data['direct_source']!,
          _directSourceMeta,
        ),
      );
    }
    if (data.containsKey('added')) {
      context.handle(
        _addedMeta,
        added.isAcceptableOrUnknown(data['added']!, _addedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, providerId},
  ];
  @override
  EpisodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      )!,
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      )!,
      episodeNum: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_num'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      containerExt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container_ext'],
      ),
      plot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plot'],
      ),
      durationSecs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_secs'],
      ),
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}release_date'],
      ),
      image: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rating'],
      ),
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      ),
      directSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direct_source'],
      ),
      added: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added'],
      ),
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class EpisodeRow extends DataClass implements Insertable<EpisodeRow> {
  final int id;
  final int playlistId;

  /// Provider episode id.
  final String providerId;

  /// Provider series id.
  final String seriesId;
  final int season;
  final int episodeNum;
  final String title;
  final String? containerExt;
  final String? plot;
  final int? durationSecs;
  final String? releaseDate;
  final String? image;
  final double? rating;
  final String? streamUrl;
  final String? directSource;
  final DateTime? added;
  const EpisodeRow({
    required this.id,
    required this.playlistId,
    required this.providerId,
    required this.seriesId,
    required this.season,
    required this.episodeNum,
    required this.title,
    this.containerExt,
    this.plot,
    this.durationSecs,
    this.releaseDate,
    this.image,
    this.rating,
    this.streamUrl,
    this.directSource,
    this.added,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['provider_id'] = Variable<String>(providerId);
    map['series_id'] = Variable<String>(seriesId);
    map['season'] = Variable<int>(season);
    map['episode_num'] = Variable<int>(episodeNum);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || containerExt != null) {
      map['container_ext'] = Variable<String>(containerExt);
    }
    if (!nullToAbsent || plot != null) {
      map['plot'] = Variable<String>(plot);
    }
    if (!nullToAbsent || durationSecs != null) {
      map['duration_secs'] = Variable<int>(durationSecs);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<String>(releaseDate);
    }
    if (!nullToAbsent || image != null) {
      map['image'] = Variable<String>(image);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || streamUrl != null) {
      map['stream_url'] = Variable<String>(streamUrl);
    }
    if (!nullToAbsent || directSource != null) {
      map['direct_source'] = Variable<String>(directSource);
    }
    if (!nullToAbsent || added != null) {
      map['added'] = Variable<DateTime>(added);
    }
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      providerId: Value(providerId),
      seriesId: Value(seriesId),
      season: Value(season),
      episodeNum: Value(episodeNum),
      title: Value(title),
      containerExt: containerExt == null && nullToAbsent
          ? const Value.absent()
          : Value(containerExt),
      plot: plot == null && nullToAbsent ? const Value.absent() : Value(plot),
      durationSecs: durationSecs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSecs),
      releaseDate: releaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseDate),
      image: image == null && nullToAbsent
          ? const Value.absent()
          : Value(image),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      streamUrl: streamUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(streamUrl),
      directSource: directSource == null && nullToAbsent
          ? const Value.absent()
          : Value(directSource),
      added: added == null && nullToAbsent
          ? const Value.absent()
          : Value(added),
    );
  }

  factory EpisodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      seriesId: serializer.fromJson<String>(json['seriesId']),
      season: serializer.fromJson<int>(json['season']),
      episodeNum: serializer.fromJson<int>(json['episodeNum']),
      title: serializer.fromJson<String>(json['title']),
      containerExt: serializer.fromJson<String?>(json['containerExt']),
      plot: serializer.fromJson<String?>(json['plot']),
      durationSecs: serializer.fromJson<int?>(json['durationSecs']),
      releaseDate: serializer.fromJson<String?>(json['releaseDate']),
      image: serializer.fromJson<String?>(json['image']),
      rating: serializer.fromJson<double?>(json['rating']),
      streamUrl: serializer.fromJson<String?>(json['streamUrl']),
      directSource: serializer.fromJson<String?>(json['directSource']),
      added: serializer.fromJson<DateTime?>(json['added']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'providerId': serializer.toJson<String>(providerId),
      'seriesId': serializer.toJson<String>(seriesId),
      'season': serializer.toJson<int>(season),
      'episodeNum': serializer.toJson<int>(episodeNum),
      'title': serializer.toJson<String>(title),
      'containerExt': serializer.toJson<String?>(containerExt),
      'plot': serializer.toJson<String?>(plot),
      'durationSecs': serializer.toJson<int?>(durationSecs),
      'releaseDate': serializer.toJson<String?>(releaseDate),
      'image': serializer.toJson<String?>(image),
      'rating': serializer.toJson<double?>(rating),
      'streamUrl': serializer.toJson<String?>(streamUrl),
      'directSource': serializer.toJson<String?>(directSource),
      'added': serializer.toJson<DateTime?>(added),
    };
  }

  EpisodeRow copyWith({
    int? id,
    int? playlistId,
    String? providerId,
    String? seriesId,
    int? season,
    int? episodeNum,
    String? title,
    Value<String?> containerExt = const Value.absent(),
    Value<String?> plot = const Value.absent(),
    Value<int?> durationSecs = const Value.absent(),
    Value<String?> releaseDate = const Value.absent(),
    Value<String?> image = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<String?> streamUrl = const Value.absent(),
    Value<String?> directSource = const Value.absent(),
    Value<DateTime?> added = const Value.absent(),
  }) => EpisodeRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    providerId: providerId ?? this.providerId,
    seriesId: seriesId ?? this.seriesId,
    season: season ?? this.season,
    episodeNum: episodeNum ?? this.episodeNum,
    title: title ?? this.title,
    containerExt: containerExt.present ? containerExt.value : this.containerExt,
    plot: plot.present ? plot.value : this.plot,
    durationSecs: durationSecs.present ? durationSecs.value : this.durationSecs,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    image: image.present ? image.value : this.image,
    rating: rating.present ? rating.value : this.rating,
    streamUrl: streamUrl.present ? streamUrl.value : this.streamUrl,
    directSource: directSource.present ? directSource.value : this.directSource,
    added: added.present ? added.value : this.added,
  );
  EpisodeRow copyWithCompanion(EpisodesCompanion data) {
    return EpisodeRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      season: data.season.present ? data.season.value : this.season,
      episodeNum: data.episodeNum.present
          ? data.episodeNum.value
          : this.episodeNum,
      title: data.title.present ? data.title.value : this.title,
      containerExt: data.containerExt.present
          ? data.containerExt.value
          : this.containerExt,
      plot: data.plot.present ? data.plot.value : this.plot,
      durationSecs: data.durationSecs.present
          ? data.durationSecs.value
          : this.durationSecs,
      releaseDate: data.releaseDate.present
          ? data.releaseDate.value
          : this.releaseDate,
      image: data.image.present ? data.image.value : this.image,
      rating: data.rating.present ? data.rating.value : this.rating,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      directSource: data.directSource.present
          ? data.directSource.value
          : this.directSource,
      added: data.added.present ? data.added.value : this.added,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('providerId: $providerId, ')
          ..write('seriesId: $seriesId, ')
          ..write('season: $season, ')
          ..write('episodeNum: $episodeNum, ')
          ..write('title: $title, ')
          ..write('containerExt: $containerExt, ')
          ..write('plot: $plot, ')
          ..write('durationSecs: $durationSecs, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('image: $image, ')
          ..write('rating: $rating, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('directSource: $directSource, ')
          ..write('added: $added')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    providerId,
    seriesId,
    season,
    episodeNum,
    title,
    containerExt,
    plot,
    durationSecs,
    releaseDate,
    image,
    rating,
    streamUrl,
    directSource,
    added,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.providerId == this.providerId &&
          other.seriesId == this.seriesId &&
          other.season == this.season &&
          other.episodeNum == this.episodeNum &&
          other.title == this.title &&
          other.containerExt == this.containerExt &&
          other.plot == this.plot &&
          other.durationSecs == this.durationSecs &&
          other.releaseDate == this.releaseDate &&
          other.image == this.image &&
          other.rating == this.rating &&
          other.streamUrl == this.streamUrl &&
          other.directSource == this.directSource &&
          other.added == this.added);
}

class EpisodesCompanion extends UpdateCompanion<EpisodeRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> providerId;
  final Value<String> seriesId;
  final Value<int> season;
  final Value<int> episodeNum;
  final Value<String> title;
  final Value<String?> containerExt;
  final Value<String?> plot;
  final Value<int?> durationSecs;
  final Value<String?> releaseDate;
  final Value<String?> image;
  final Value<double?> rating;
  final Value<String?> streamUrl;
  final Value<String?> directSource;
  final Value<DateTime?> added;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.season = const Value.absent(),
    this.episodeNum = const Value.absent(),
    this.title = const Value.absent(),
    this.containerExt = const Value.absent(),
    this.plot = const Value.absent(),
    this.durationSecs = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.image = const Value.absent(),
    this.rating = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.directSource = const Value.absent(),
    this.added = const Value.absent(),
  });
  EpisodesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String providerId,
    required String seriesId,
    required int season,
    required int episodeNum,
    required String title,
    this.containerExt = const Value.absent(),
    this.plot = const Value.absent(),
    this.durationSecs = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.image = const Value.absent(),
    this.rating = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.directSource = const Value.absent(),
    this.added = const Value.absent(),
  }) : playlistId = Value(playlistId),
       providerId = Value(providerId),
       seriesId = Value(seriesId),
       season = Value(season),
       episodeNum = Value(episodeNum),
       title = Value(title);
  static Insertable<EpisodeRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? providerId,
    Expression<String>? seriesId,
    Expression<int>? season,
    Expression<int>? episodeNum,
    Expression<String>? title,
    Expression<String>? containerExt,
    Expression<String>? plot,
    Expression<int>? durationSecs,
    Expression<String>? releaseDate,
    Expression<String>? image,
    Expression<double>? rating,
    Expression<String>? streamUrl,
    Expression<String>? directSource,
    Expression<DateTime>? added,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (providerId != null) 'provider_id': providerId,
      if (seriesId != null) 'series_id': seriesId,
      if (season != null) 'season': season,
      if (episodeNum != null) 'episode_num': episodeNum,
      if (title != null) 'title': title,
      if (containerExt != null) 'container_ext': containerExt,
      if (plot != null) 'plot': plot,
      if (durationSecs != null) 'duration_secs': durationSecs,
      if (releaseDate != null) 'release_date': releaseDate,
      if (image != null) 'image': image,
      if (rating != null) 'rating': rating,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (directSource != null) 'direct_source': directSource,
      if (added != null) 'added': added,
    });
  }

  EpisodesCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? providerId,
    Value<String>? seriesId,
    Value<int>? season,
    Value<int>? episodeNum,
    Value<String>? title,
    Value<String?>? containerExt,
    Value<String?>? plot,
    Value<int?>? durationSecs,
    Value<String?>? releaseDate,
    Value<String?>? image,
    Value<double?>? rating,
    Value<String?>? streamUrl,
    Value<String?>? directSource,
    Value<DateTime?>? added,
  }) {
    return EpisodesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      providerId: providerId ?? this.providerId,
      seriesId: seriesId ?? this.seriesId,
      season: season ?? this.season,
      episodeNum: episodeNum ?? this.episodeNum,
      title: title ?? this.title,
      containerExt: containerExt ?? this.containerExt,
      plot: plot ?? this.plot,
      durationSecs: durationSecs ?? this.durationSecs,
      releaseDate: releaseDate ?? this.releaseDate,
      image: image ?? this.image,
      rating: rating ?? this.rating,
      streamUrl: streamUrl ?? this.streamUrl,
      directSource: directSource ?? this.directSource,
      added: added ?? this.added,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episodeNum.present) {
      map['episode_num'] = Variable<int>(episodeNum.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (containerExt.present) {
      map['container_ext'] = Variable<String>(containerExt.value);
    }
    if (plot.present) {
      map['plot'] = Variable<String>(plot.value);
    }
    if (durationSecs.present) {
      map['duration_secs'] = Variable<int>(durationSecs.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<String>(releaseDate.value);
    }
    if (image.present) {
      map['image'] = Variable<String>(image.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (directSource.present) {
      map['direct_source'] = Variable<String>(directSource.value);
    }
    if (added.present) {
      map['added'] = Variable<DateTime>(added.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('providerId: $providerId, ')
          ..write('seriesId: $seriesId, ')
          ..write('season: $season, ')
          ..write('episodeNum: $episodeNum, ')
          ..write('title: $title, ')
          ..write('containerExt: $containerExt, ')
          ..write('plot: $plot, ')
          ..write('durationSecs: $durationSecs, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('image: $image, ')
          ..write('rating: $rating, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('directSource: $directSource, ')
          ..write('added: $added')
          ..write(')'))
        .toString();
  }
}

class $EpgChannelsTable extends EpgChannels
    with TableInfo<$EpgChannelsTable, EpgChannelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpgChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _epgIdMeta = const VerificationMeta('epgId');
  @override
  late final GeneratedColumn<String> epgId = GeneratedColumn<String>(
    'epg_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedMeta = const VerificationMeta(
    'normalized',
  );
  @override
  late final GeneratedColumn<String> normalized = GeneratedColumn<String>(
    'normalized',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    epgId,
    displayName,
    normalized,
    icon,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epg_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpgChannelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('epg_id')) {
      context.handle(
        _epgIdMeta,
        epgId.isAcceptableOrUnknown(data['epg_id']!, _epgIdMeta),
      );
    } else if (isInserting) {
      context.missing(_epgIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('normalized')) {
      context.handle(
        _normalizedMeta,
        normalized.isAcceptableOrUnknown(data['normalized']!, _normalizedMeta),
      );
    } else if (isInserting) {
      context.missing(_normalizedMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, epgId},
  ];
  @override
  EpgChannelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpgChannelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      epgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      normalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
    );
  }

  @override
  $EpgChannelsTable createAlias(String alias) {
    return $EpgChannelsTable(attachedDatabase, alias);
  }
}

class EpgChannelRow extends DataClass implements Insertable<EpgChannelRow> {
  final int id;
  final int playlistId;
  final String epgId;
  final String displayName;

  /// Normalized display name (see data/text/normalize.dart).
  final String normalized;
  final String? icon;
  const EpgChannelRow({
    required this.id,
    required this.playlistId,
    required this.epgId,
    required this.displayName,
    required this.normalized,
    this.icon,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['epg_id'] = Variable<String>(epgId);
    map['display_name'] = Variable<String>(displayName);
    map['normalized'] = Variable<String>(normalized);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    return map;
  }

  EpgChannelsCompanion toCompanion(bool nullToAbsent) {
    return EpgChannelsCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      epgId: Value(epgId),
      displayName: Value(displayName),
      normalized: Value(normalized),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
    );
  }

  factory EpgChannelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpgChannelRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      epgId: serializer.fromJson<String>(json['epgId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      normalized: serializer.fromJson<String>(json['normalized']),
      icon: serializer.fromJson<String?>(json['icon']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'epgId': serializer.toJson<String>(epgId),
      'displayName': serializer.toJson<String>(displayName),
      'normalized': serializer.toJson<String>(normalized),
      'icon': serializer.toJson<String?>(icon),
    };
  }

  EpgChannelRow copyWith({
    int? id,
    int? playlistId,
    String? epgId,
    String? displayName,
    String? normalized,
    Value<String?> icon = const Value.absent(),
  }) => EpgChannelRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    epgId: epgId ?? this.epgId,
    displayName: displayName ?? this.displayName,
    normalized: normalized ?? this.normalized,
    icon: icon.present ? icon.value : this.icon,
  );
  EpgChannelRow copyWithCompanion(EpgChannelsCompanion data) {
    return EpgChannelRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      epgId: data.epgId.present ? data.epgId.value : this.epgId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      normalized: data.normalized.present
          ? data.normalized.value
          : this.normalized,
      icon: data.icon.present ? data.icon.value : this.icon,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannelRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('epgId: $epgId, ')
          ..write('displayName: $displayName, ')
          ..write('normalized: $normalized, ')
          ..write('icon: $icon')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, playlistId, epgId, displayName, normalized, icon);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpgChannelRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.epgId == this.epgId &&
          other.displayName == this.displayName &&
          other.normalized == this.normalized &&
          other.icon == this.icon);
}

class EpgChannelsCompanion extends UpdateCompanion<EpgChannelRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> epgId;
  final Value<String> displayName;
  final Value<String> normalized;
  final Value<String?> icon;
  const EpgChannelsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.epgId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.normalized = const Value.absent(),
    this.icon = const Value.absent(),
  });
  EpgChannelsCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String epgId,
    required String displayName,
    required String normalized,
    this.icon = const Value.absent(),
  }) : playlistId = Value(playlistId),
       epgId = Value(epgId),
       displayName = Value(displayName),
       normalized = Value(normalized);
  static Insertable<EpgChannelRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? epgId,
    Expression<String>? displayName,
    Expression<String>? normalized,
    Expression<String>? icon,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (epgId != null) 'epg_id': epgId,
      if (displayName != null) 'display_name': displayName,
      if (normalized != null) 'normalized': normalized,
      if (icon != null) 'icon': icon,
    });
  }

  EpgChannelsCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? epgId,
    Value<String>? displayName,
    Value<String>? normalized,
    Value<String?>? icon,
  }) {
    return EpgChannelsCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      epgId: epgId ?? this.epgId,
      displayName: displayName ?? this.displayName,
      normalized: normalized ?? this.normalized,
      icon: icon ?? this.icon,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (epgId.present) {
      map['epg_id'] = Variable<String>(epgId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (normalized.present) {
      map['normalized'] = Variable<String>(normalized.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpgChannelsCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('epgId: $epgId, ')
          ..write('displayName: $displayName, ')
          ..write('normalized: $normalized, ')
          ..write('icon: $icon')
          ..write(')'))
        .toString();
  }
}

class $ProgrammesTable extends Programmes
    with TableInfo<$ProgrammesTable, ProgrammeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgrammesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<int> start = GeneratedColumn<int>(
    'start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stopMeta = const VerificationMeta('stop');
  @override
  late final GeneratedColumn<int> stop = GeneratedColumn<int>(
    'stop',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subTitleMeta = const VerificationMeta(
    'subTitle',
  );
  @override
  late final GeneratedColumn<String> subTitle = GeneratedColumn<String>(
    'sub_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeNumMeta = const VerificationMeta(
    'episodeNum',
  );
  @override
  late final GeneratedColumn<String> episodeNum = GeneratedColumn<String>(
    'episode_num',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    epgChannelId,
    start,
    stop,
    title,
    subTitle,
    description,
    category,
    episodeNum,
    icon,
    rating,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'programmes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgrammeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_epgChannelIdMeta);
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('stop')) {
      context.handle(
        _stopMeta,
        stop.isAcceptableOrUnknown(data['stop']!, _stopMeta),
      );
    } else if (isInserting) {
      context.missing(_stopMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('sub_title')) {
      context.handle(
        _subTitleMeta,
        subTitle.isAcceptableOrUnknown(data['sub_title']!, _subTitleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('episode_num')) {
      context.handle(
        _episodeNumMeta,
        episodeNum.isAcceptableOrUnknown(data['episode_num']!, _episodeNumMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProgrammeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgrammeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      )!,
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start'],
      )!,
      stop: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stop'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_title'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      episodeNum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_num'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating'],
      ),
    );
  }

  @override
  $ProgrammesTable createAlias(String alias) {
    return $ProgrammesTable(attachedDatabase, alias);
  }
}

class ProgrammeRow extends DataClass implements Insertable<ProgrammeRow> {
  final int id;
  final int playlistId;
  final String epgChannelId;
  final int start;
  final int stop;
  final String title;
  final String? subTitle;
  final String? description;
  final String? category;
  final String? episodeNum;
  final String? icon;
  final String? rating;
  const ProgrammeRow({
    required this.id,
    required this.playlistId,
    required this.epgChannelId,
    required this.start,
    required this.stop,
    required this.title,
    this.subTitle,
    this.description,
    this.category,
    this.episodeNum,
    this.icon,
    this.rating,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['epg_channel_id'] = Variable<String>(epgChannelId);
    map['start'] = Variable<int>(start);
    map['stop'] = Variable<int>(stop);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || subTitle != null) {
      map['sub_title'] = Variable<String>(subTitle);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || episodeNum != null) {
      map['episode_num'] = Variable<String>(episodeNum);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<String>(rating);
    }
    return map;
  }

  ProgrammesCompanion toCompanion(bool nullToAbsent) {
    return ProgrammesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      epgChannelId: Value(epgChannelId),
      start: Value(start),
      stop: Value(stop),
      title: Value(title),
      subTitle: subTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(subTitle),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      episodeNum: episodeNum == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeNum),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
    );
  }

  factory ProgrammeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgrammeRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      epgChannelId: serializer.fromJson<String>(json['epgChannelId']),
      start: serializer.fromJson<int>(json['start']),
      stop: serializer.fromJson<int>(json['stop']),
      title: serializer.fromJson<String>(json['title']),
      subTitle: serializer.fromJson<String?>(json['subTitle']),
      description: serializer.fromJson<String?>(json['description']),
      category: serializer.fromJson<String?>(json['category']),
      episodeNum: serializer.fromJson<String?>(json['episodeNum']),
      icon: serializer.fromJson<String?>(json['icon']),
      rating: serializer.fromJson<String?>(json['rating']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'epgChannelId': serializer.toJson<String>(epgChannelId),
      'start': serializer.toJson<int>(start),
      'stop': serializer.toJson<int>(stop),
      'title': serializer.toJson<String>(title),
      'subTitle': serializer.toJson<String?>(subTitle),
      'description': serializer.toJson<String?>(description),
      'category': serializer.toJson<String?>(category),
      'episodeNum': serializer.toJson<String?>(episodeNum),
      'icon': serializer.toJson<String?>(icon),
      'rating': serializer.toJson<String?>(rating),
    };
  }

  ProgrammeRow copyWith({
    int? id,
    int? playlistId,
    String? epgChannelId,
    int? start,
    int? stop,
    String? title,
    Value<String?> subTitle = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> episodeNum = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<String?> rating = const Value.absent(),
  }) => ProgrammeRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    epgChannelId: epgChannelId ?? this.epgChannelId,
    start: start ?? this.start,
    stop: stop ?? this.stop,
    title: title ?? this.title,
    subTitle: subTitle.present ? subTitle.value : this.subTitle,
    description: description.present ? description.value : this.description,
    category: category.present ? category.value : this.category,
    episodeNum: episodeNum.present ? episodeNum.value : this.episodeNum,
    icon: icon.present ? icon.value : this.icon,
    rating: rating.present ? rating.value : this.rating,
  );
  ProgrammeRow copyWithCompanion(ProgrammesCompanion data) {
    return ProgrammeRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      start: data.start.present ? data.start.value : this.start,
      stop: data.stop.present ? data.stop.value : this.stop,
      title: data.title.present ? data.title.value : this.title,
      subTitle: data.subTitle.present ? data.subTitle.value : this.subTitle,
      description: data.description.present
          ? data.description.value
          : this.description,
      category: data.category.present ? data.category.value : this.category,
      episodeNum: data.episodeNum.present
          ? data.episodeNum.value
          : this.episodeNum,
      icon: data.icon.present ? data.icon.value : this.icon,
      rating: data.rating.present ? data.rating.value : this.rating,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgrammeRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('start: $start, ')
          ..write('stop: $stop, ')
          ..write('title: $title, ')
          ..write('subTitle: $subTitle, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('episodeNum: $episodeNum, ')
          ..write('icon: $icon, ')
          ..write('rating: $rating')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    epgChannelId,
    start,
    stop,
    title,
    subTitle,
    description,
    category,
    episodeNum,
    icon,
    rating,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgrammeRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.epgChannelId == this.epgChannelId &&
          other.start == this.start &&
          other.stop == this.stop &&
          other.title == this.title &&
          other.subTitle == this.subTitle &&
          other.description == this.description &&
          other.category == this.category &&
          other.episodeNum == this.episodeNum &&
          other.icon == this.icon &&
          other.rating == this.rating);
}

class ProgrammesCompanion extends UpdateCompanion<ProgrammeRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> epgChannelId;
  final Value<int> start;
  final Value<int> stop;
  final Value<String> title;
  final Value<String?> subTitle;
  final Value<String?> description;
  final Value<String?> category;
  final Value<String?> episodeNum;
  final Value<String?> icon;
  final Value<String?> rating;
  const ProgrammesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.start = const Value.absent(),
    this.stop = const Value.absent(),
    this.title = const Value.absent(),
    this.subTitle = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.episodeNum = const Value.absent(),
    this.icon = const Value.absent(),
    this.rating = const Value.absent(),
  });
  ProgrammesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String epgChannelId,
    required int start,
    required int stop,
    required String title,
    this.subTitle = const Value.absent(),
    this.description = const Value.absent(),
    this.category = const Value.absent(),
    this.episodeNum = const Value.absent(),
    this.icon = const Value.absent(),
    this.rating = const Value.absent(),
  }) : playlistId = Value(playlistId),
       epgChannelId = Value(epgChannelId),
       start = Value(start),
       stop = Value(stop),
       title = Value(title);
  static Insertable<ProgrammeRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? epgChannelId,
    Expression<int>? start,
    Expression<int>? stop,
    Expression<String>? title,
    Expression<String>? subTitle,
    Expression<String>? description,
    Expression<String>? category,
    Expression<String>? episodeNum,
    Expression<String>? icon,
    Expression<String>? rating,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (start != null) 'start': start,
      if (stop != null) 'stop': stop,
      if (title != null) 'title': title,
      if (subTitle != null) 'sub_title': subTitle,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (episodeNum != null) 'episode_num': episodeNum,
      if (icon != null) 'icon': icon,
      if (rating != null) 'rating': rating,
    });
  }

  ProgrammesCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? epgChannelId,
    Value<int>? start,
    Value<int>? stop,
    Value<String>? title,
    Value<String?>? subTitle,
    Value<String?>? description,
    Value<String?>? category,
    Value<String?>? episodeNum,
    Value<String?>? icon,
    Value<String?>? rating,
  }) {
    return ProgrammesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      start: start ?? this.start,
      stop: stop ?? this.stop,
      title: title ?? this.title,
      subTitle: subTitle ?? this.subTitle,
      description: description ?? this.description,
      category: category ?? this.category,
      episodeNum: episodeNum ?? this.episodeNum,
      icon: icon ?? this.icon,
      rating: rating ?? this.rating,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (start.present) {
      map['start'] = Variable<int>(start.value);
    }
    if (stop.present) {
      map['stop'] = Variable<int>(stop.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subTitle.present) {
      map['sub_title'] = Variable<String>(subTitle.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (episodeNum.present) {
      map['episode_num'] = Variable<String>(episodeNum.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgrammesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('start: $start, ')
          ..write('stop: $stop, ')
          ..write('title: $title, ')
          ..write('subTitle: $subTitle, ')
          ..write('description: $description, ')
          ..write('category: $category, ')
          ..write('episodeNum: $episodeNum, ')
          ..write('icon: $icon, ')
          ..write('rating: $rating')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemType, int> itemType =
      GeneratedColumn<int>(
        'item_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ItemType>($FavoritesTable.$converteritemType);
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customIndexMeta = const VerificationMeta(
    'customIndex',
  );
  @override
  late final GeneratedColumn<int> customIndex = GeneratedColumn<int>(
    'custom_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    itemType,
    providerId,
    addedAt,
    customIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('custom_index')) {
      context.handle(
        _customIndexMeta,
        customIndex.isAcceptableOrUnknown(
          data['custom_index']!,
          _customIndexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, itemType, providerId},
  ];
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      itemType: $FavoritesTable.$converteritemType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}item_type'],
        )!,
      ),
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      customIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_index'],
      ),
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemType, int, int> $converteritemType =
      const EnumIndexConverter<ItemType>(ItemType.values);
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final int id;
  final int playlistId;
  final ItemType itemType;
  final String providerId;
  final DateTime addedAt;
  final int? customIndex;
  const FavoriteRow({
    required this.id,
    required this.playlistId,
    required this.itemType,
    required this.providerId,
    required this.addedAt,
    this.customIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    {
      map['item_type'] = Variable<int>(
        $FavoritesTable.$converteritemType.toSql(itemType),
      );
    }
    map['provider_id'] = Variable<String>(providerId);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || customIndex != null) {
      map['custom_index'] = Variable<int>(customIndex);
    }
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      itemType: Value(itemType),
      providerId: Value(providerId),
      addedAt: Value(addedAt),
      customIndex: customIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(customIndex),
    );
  }

  factory FavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      itemType: $FavoritesTable.$converteritemType.fromJson(
        serializer.fromJson<int>(json['itemType']),
      ),
      providerId: serializer.fromJson<String>(json['providerId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      customIndex: serializer.fromJson<int?>(json['customIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'itemType': serializer.toJson<int>(
        $FavoritesTable.$converteritemType.toJson(itemType),
      ),
      'providerId': serializer.toJson<String>(providerId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'customIndex': serializer.toJson<int?>(customIndex),
    };
  }

  FavoriteRow copyWith({
    int? id,
    int? playlistId,
    ItemType? itemType,
    String? providerId,
    DateTime? addedAt,
    Value<int?> customIndex = const Value.absent(),
  }) => FavoriteRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    itemType: itemType ?? this.itemType,
    providerId: providerId ?? this.providerId,
    addedAt: addedAt ?? this.addedAt,
    customIndex: customIndex.present ? customIndex.value : this.customIndex,
  );
  FavoriteRow copyWithCompanion(FavoritesCompanion data) {
    return FavoriteRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      customIndex: data.customIndex.present
          ? data.customIndex.value
          : this.customIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('itemType: $itemType, ')
          ..write('providerId: $providerId, ')
          ..write('addedAt: $addedAt, ')
          ..write('customIndex: $customIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, playlistId, itemType, providerId, addedAt, customIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.itemType == this.itemType &&
          other.providerId == this.providerId &&
          other.addedAt == this.addedAt &&
          other.customIndex == this.customIndex);
}

class FavoritesCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<ItemType> itemType;
  final Value<String> providerId;
  final Value<DateTime> addedAt;
  final Value<int?> customIndex;
  const FavoritesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.providerId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.customIndex = const Value.absent(),
  });
  FavoritesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required ItemType itemType,
    required String providerId,
    required DateTime addedAt,
    this.customIndex = const Value.absent(),
  }) : playlistId = Value(playlistId),
       itemType = Value(itemType),
       providerId = Value(providerId),
       addedAt = Value(addedAt);
  static Insertable<FavoriteRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<int>? itemType,
    Expression<String>? providerId,
    Expression<DateTime>? addedAt,
    Expression<int>? customIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (itemType != null) 'item_type': itemType,
      if (providerId != null) 'provider_id': providerId,
      if (addedAt != null) 'added_at': addedAt,
      if (customIndex != null) 'custom_index': customIndex,
    });
  }

  FavoritesCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<ItemType>? itemType,
    Value<String>? providerId,
    Value<DateTime>? addedAt,
    Value<int?>? customIndex,
  }) {
    return FavoritesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      itemType: itemType ?? this.itemType,
      providerId: providerId ?? this.providerId,
      addedAt: addedAt ?? this.addedAt,
      customIndex: customIndex ?? this.customIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<int>(
        $FavoritesTable.$converteritemType.toSql(itemType.value),
      );
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (customIndex.present) {
      map['custom_index'] = Variable<int>(customIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('itemType: $itemType, ')
          ..write('providerId: $providerId, ')
          ..write('addedAt: $addedAt, ')
          ..write('customIndex: $customIndex')
          ..write(')'))
        .toString();
  }
}

class $FavoriteTagsTable extends FavoriteTags
    with TableInfo<$FavoriteTagsTable, FavoriteTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, playlistId, name, sortIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, name},
  ];
  @override
  FavoriteTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteTagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $FavoriteTagsTable createAlias(String alias) {
    return $FavoriteTagsTable(attachedDatabase, alias);
  }
}

class FavoriteTagRow extends DataClass implements Insertable<FavoriteTagRow> {
  final int id;
  final int playlistId;
  final String name;
  final int sortIndex;
  const FavoriteTagRow({
    required this.id,
    required this.playlistId,
    required this.name,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['name'] = Variable<String>(name);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  FavoriteTagsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteTagsCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      name: Value(name),
      sortIndex: Value(sortIndex),
    );
  }

  factory FavoriteTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteTagRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      name: serializer.fromJson<String>(json['name']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'name': serializer.toJson<String>(name),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  FavoriteTagRow copyWith({
    int? id,
    int? playlistId,
    String? name,
    int? sortIndex,
  }) => FavoriteTagRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    name: name ?? this.name,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  FavoriteTagRow copyWithCompanion(FavoriteTagsCompanion data) {
    return FavoriteTagRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      name: data.name.present ? data.name.value : this.name,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteTagRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('name: $name, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, playlistId, name, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteTagRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.name == this.name &&
          other.sortIndex == this.sortIndex);
}

class FavoriteTagsCompanion extends UpdateCompanion<FavoriteTagRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> name;
  final Value<int> sortIndex;
  const FavoriteTagsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortIndex = const Value.absent(),
  });
  FavoriteTagsCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String name,
    this.sortIndex = const Value.absent(),
  }) : playlistId = Value(playlistId),
       name = Value(name);
  static Insertable<FavoriteTagRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? name,
    Expression<int>? sortIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (name != null) 'name': name,
      if (sortIndex != null) 'sort_index': sortIndex,
    });
  }

  FavoriteTagsCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? name,
    Value<int>? sortIndex,
  }) {
    return FavoriteTagsCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      name: name ?? this.name,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteTagsCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('name: $name, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }
}

class $FavoriteTagLinksTable extends FavoriteTagLinks
    with TableInfo<$FavoriteTagLinksTable, FavoriteTagLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteTagLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _favoriteIdMeta = const VerificationMeta(
    'favoriteId',
  );
  @override
  late final GeneratedColumn<int> favoriteId = GeneratedColumn<int>(
    'favorite_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES favorites (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES favorite_tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [favoriteId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_tag_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteTagLinkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('favorite_id')) {
      context.handle(
        _favoriteIdMeta,
        favoriteId.isAcceptableOrUnknown(data['favorite_id']!, _favoriteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_favoriteIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {favoriteId, tagId};
  @override
  FavoriteTagLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteTagLinkRow(
      favoriteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorite_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $FavoriteTagLinksTable createAlias(String alias) {
    return $FavoriteTagLinksTable(attachedDatabase, alias);
  }
}

class FavoriteTagLinkRow extends DataClass
    implements Insertable<FavoriteTagLinkRow> {
  final int favoriteId;
  final int tagId;
  const FavoriteTagLinkRow({required this.favoriteId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['favorite_id'] = Variable<int>(favoriteId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  FavoriteTagLinksCompanion toCompanion(bool nullToAbsent) {
    return FavoriteTagLinksCompanion(
      favoriteId: Value(favoriteId),
      tagId: Value(tagId),
    );
  }

  factory FavoriteTagLinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteTagLinkRow(
      favoriteId: serializer.fromJson<int>(json['favoriteId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'favoriteId': serializer.toJson<int>(favoriteId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  FavoriteTagLinkRow copyWith({int? favoriteId, int? tagId}) =>
      FavoriteTagLinkRow(
        favoriteId: favoriteId ?? this.favoriteId,
        tagId: tagId ?? this.tagId,
      );
  FavoriteTagLinkRow copyWithCompanion(FavoriteTagLinksCompanion data) {
    return FavoriteTagLinkRow(
      favoriteId: data.favoriteId.present
          ? data.favoriteId.value
          : this.favoriteId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteTagLinkRow(')
          ..write('favoriteId: $favoriteId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(favoriteId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteTagLinkRow &&
          other.favoriteId == this.favoriteId &&
          other.tagId == this.tagId);
}

class FavoriteTagLinksCompanion extends UpdateCompanion<FavoriteTagLinkRow> {
  final Value<int> favoriteId;
  final Value<int> tagId;
  final Value<int> rowid;
  const FavoriteTagLinksCompanion({
    this.favoriteId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteTagLinksCompanion.insert({
    required int favoriteId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : favoriteId = Value(favoriteId),
       tagId = Value(tagId);
  static Insertable<FavoriteTagLinkRow> custom({
    Expression<int>? favoriteId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (favoriteId != null) 'favorite_id': favoriteId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteTagLinksCompanion copyWith({
    Value<int>? favoriteId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return FavoriteTagLinksCompanion(
      favoriteId: favoriteId ?? this.favoriteId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (favoriteId.present) {
      map['favorite_id'] = Variable<int>(favoriteId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteTagLinksCompanion(')
          ..write('favoriteId: $favoriteId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchStatesTable extends WatchStates
    with TableInfo<$WatchStatesTable, WatchStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemType, int> itemType =
      GeneratedColumn<int>(
        'item_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ItemType>($WatchStatesTable.$converteritemType);
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _watchedMeta = const VerificationMeta(
    'watched',
  );
  @override
  late final GeneratedColumn<bool> watched = GeneratedColumn<bool>(
    'watched',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("watched" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    itemType,
    providerId,
    seriesId,
    positionMs,
    durationMs,
    watched,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('watched')) {
      context.handle(
        _watchedMeta,
        watched.isAcceptableOrUnknown(data['watched']!, _watchedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, itemType, providerId};
  @override
  WatchStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchStateRow(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      itemType: $WatchStatesTable.$converteritemType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}item_type'],
        )!,
      ),
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      ),
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      watched: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}watched'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WatchStatesTable createAlias(String alias) {
    return $WatchStatesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemType, int, int> $converteritemType =
      const EnumIndexConverter<ItemType>(ItemType.values);
}

class WatchStateRow extends DataClass implements Insertable<WatchStateRow> {
  final int playlistId;
  final ItemType itemType;
  final String providerId;

  /// For episodes: the provider series id (drives Shows "Continue watching").
  final String? seriesId;
  final int positionMs;
  final int durationMs;
  final bool watched;
  final DateTime updatedAt;
  const WatchStateRow({
    required this.playlistId,
    required this.itemType,
    required this.providerId,
    this.seriesId,
    required this.positionMs,
    required this.durationMs,
    required this.watched,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    {
      map['item_type'] = Variable<int>(
        $WatchStatesTable.$converteritemType.toSql(itemType),
      );
    }
    map['provider_id'] = Variable<String>(providerId);
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<String>(seriesId);
    }
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['watched'] = Variable<bool>(watched);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WatchStatesCompanion toCompanion(bool nullToAbsent) {
    return WatchStatesCompanion(
      playlistId: Value(playlistId),
      itemType: Value(itemType),
      providerId: Value(providerId),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      watched: Value(watched),
      updatedAt: Value(updatedAt),
    );
  }

  factory WatchStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchStateRow(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      itemType: $WatchStatesTable.$converteritemType.fromJson(
        serializer.fromJson<int>(json['itemType']),
      ),
      providerId: serializer.fromJson<String>(json['providerId']),
      seriesId: serializer.fromJson<String?>(json['seriesId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      watched: serializer.fromJson<bool>(json['watched']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'itemType': serializer.toJson<int>(
        $WatchStatesTable.$converteritemType.toJson(itemType),
      ),
      'providerId': serializer.toJson<String>(providerId),
      'seriesId': serializer.toJson<String?>(seriesId),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'watched': serializer.toJson<bool>(watched),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WatchStateRow copyWith({
    int? playlistId,
    ItemType? itemType,
    String? providerId,
    Value<String?> seriesId = const Value.absent(),
    int? positionMs,
    int? durationMs,
    bool? watched,
    DateTime? updatedAt,
  }) => WatchStateRow(
    playlistId: playlistId ?? this.playlistId,
    itemType: itemType ?? this.itemType,
    providerId: providerId ?? this.providerId,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    watched: watched ?? this.watched,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WatchStateRow copyWithCompanion(WatchStatesCompanion data) {
    return WatchStateRow(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      watched: data.watched.present ? data.watched.value : this.watched,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchStateRow(')
          ..write('playlistId: $playlistId, ')
          ..write('itemType: $itemType, ')
          ..write('providerId: $providerId, ')
          ..write('seriesId: $seriesId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('watched: $watched, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playlistId,
    itemType,
    providerId,
    seriesId,
    positionMs,
    durationMs,
    watched,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchStateRow &&
          other.playlistId == this.playlistId &&
          other.itemType == this.itemType &&
          other.providerId == this.providerId &&
          other.seriesId == this.seriesId &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.watched == this.watched &&
          other.updatedAt == this.updatedAt);
}

class WatchStatesCompanion extends UpdateCompanion<WatchStateRow> {
  final Value<int> playlistId;
  final Value<ItemType> itemType;
  final Value<String> providerId;
  final Value<String?> seriesId;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<bool> watched;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WatchStatesCompanion({
    this.playlistId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.providerId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.watched = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchStatesCompanion.insert({
    required int playlistId,
    required ItemType itemType,
    required String providerId,
    this.seriesId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.watched = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       itemType = Value(itemType),
       providerId = Value(providerId),
       updatedAt = Value(updatedAt);
  static Insertable<WatchStateRow> custom({
    Expression<int>? playlistId,
    Expression<int>? itemType,
    Expression<String>? providerId,
    Expression<String>? seriesId,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<bool>? watched,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (itemType != null) 'item_type': itemType,
      if (providerId != null) 'provider_id': providerId,
      if (seriesId != null) 'series_id': seriesId,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (watched != null) 'watched': watched,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchStatesCompanion copyWith({
    Value<int>? playlistId,
    Value<ItemType>? itemType,
    Value<String>? providerId,
    Value<String?>? seriesId,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<bool>? watched,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WatchStatesCompanion(
      playlistId: playlistId ?? this.playlistId,
      itemType: itemType ?? this.itemType,
      providerId: providerId ?? this.providerId,
      seriesId: seriesId ?? this.seriesId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      watched: watched ?? this.watched,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<int>(
        $WatchStatesTable.$converteritemType.toSql(itemType.value),
      );
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (watched.present) {
      map['watched'] = Variable<bool>(watched.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchStatesCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('itemType: $itemType, ')
          ..write('providerId: $providerId, ')
          ..write('seriesId: $seriesId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('watched: $watched, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LastWatchedLiveTable extends LastWatchedLive
    with TableInfo<$LastWatchedLiveTable, LastWatchedLiveRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LastWatchedLiveTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _watchedAtMeta = const VerificationMeta(
    'watchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> watchedAt = GeneratedColumn<DateTime>(
    'watched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [playlistId, channelId, watchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'last_watched_live';
  @override
  VerificationContext validateIntegrity(
    Insertable<LastWatchedLiveRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('watched_at')) {
      context.handle(
        _watchedAtMeta,
        watchedAt.isAcceptableOrUnknown(data['watched_at']!, _watchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_watchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, channelId};
  @override
  LastWatchedLiveRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LastWatchedLiveRow(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      watchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}watched_at'],
      )!,
    );
  }

  @override
  $LastWatchedLiveTable createAlias(String alias) {
    return $LastWatchedLiveTable(attachedDatabase, alias);
  }
}

class LastWatchedLiveRow extends DataClass
    implements Insertable<LastWatchedLiveRow> {
  final int playlistId;
  final String channelId;
  final DateTime watchedAt;
  const LastWatchedLiveRow({
    required this.playlistId,
    required this.channelId,
    required this.watchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['channel_id'] = Variable<String>(channelId);
    map['watched_at'] = Variable<DateTime>(watchedAt);
    return map;
  }

  LastWatchedLiveCompanion toCompanion(bool nullToAbsent) {
    return LastWatchedLiveCompanion(
      playlistId: Value(playlistId),
      channelId: Value(channelId),
      watchedAt: Value(watchedAt),
    );
  }

  factory LastWatchedLiveRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LastWatchedLiveRow(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      watchedAt: serializer.fromJson<DateTime>(json['watchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'channelId': serializer.toJson<String>(channelId),
      'watchedAt': serializer.toJson<DateTime>(watchedAt),
    };
  }

  LastWatchedLiveRow copyWith({
    int? playlistId,
    String? channelId,
    DateTime? watchedAt,
  }) => LastWatchedLiveRow(
    playlistId: playlistId ?? this.playlistId,
    channelId: channelId ?? this.channelId,
    watchedAt: watchedAt ?? this.watchedAt,
  );
  LastWatchedLiveRow copyWithCompanion(LastWatchedLiveCompanion data) {
    return LastWatchedLiveRow(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      watchedAt: data.watchedAt.present ? data.watchedAt.value : this.watchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LastWatchedLiveRow(')
          ..write('playlistId: $playlistId, ')
          ..write('channelId: $channelId, ')
          ..write('watchedAt: $watchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, channelId, watchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LastWatchedLiveRow &&
          other.playlistId == this.playlistId &&
          other.channelId == this.channelId &&
          other.watchedAt == this.watchedAt);
}

class LastWatchedLiveCompanion extends UpdateCompanion<LastWatchedLiveRow> {
  final Value<int> playlistId;
  final Value<String> channelId;
  final Value<DateTime> watchedAt;
  final Value<int> rowid;
  const LastWatchedLiveCompanion({
    this.playlistId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.watchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LastWatchedLiveCompanion.insert({
    required int playlistId,
    required String channelId,
    required DateTime watchedAt,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       channelId = Value(channelId),
       watchedAt = Value(watchedAt);
  static Insertable<LastWatchedLiveRow> custom({
    Expression<int>? playlistId,
    Expression<String>? channelId,
    Expression<DateTime>? watchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (channelId != null) 'channel_id': channelId,
      if (watchedAt != null) 'watched_at': watchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LastWatchedLiveCompanion copyWith({
    Value<int>? playlistId,
    Value<String>? channelId,
    Value<DateTime>? watchedAt,
    Value<int>? rowid,
  }) {
    return LastWatchedLiveCompanion(
      playlistId: playlistId ?? this.playlistId,
      channelId: channelId ?? this.channelId,
      watchedAt: watchedAt ?? this.watchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (watchedAt.present) {
      map['watched_at'] = Variable<DateTime>(watchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LastWatchedLiveCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('channelId: $channelId, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelNameMeta = const VerificationMeta(
    'channelName',
  );
  @override
  late final GeneratedColumn<String> channelName = GeneratedColumn<String>(
    'channel_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epgChannelIdMeta = const VerificationMeta(
    'epgChannelId',
  );
  @override
  late final GeneratedColumn<String> epgChannelId = GeneratedColumn<String>(
    'epg_channel_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<int> start = GeneratedColumn<int>(
    'start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stopMeta = const VerificationMeta('stop');
  @override
  late final GeneratedColumn<int> stop = GeneratedColumn<int>(
    'stop',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firedMeta = const VerificationMeta('fired');
  @override
  late final GeneratedColumn<bool> fired = GeneratedColumn<bool>(
    'fired',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fired" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    channelId,
    channelName,
    epgChannelId,
    title,
    start,
    stop,
    fired,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('channel_name')) {
      context.handle(
        _channelNameMeta,
        channelName.isAcceptableOrUnknown(
          data['channel_name']!,
          _channelNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_channelNameMeta);
    }
    if (data.containsKey('epg_channel_id')) {
      context.handle(
        _epgChannelIdMeta,
        epgChannelId.isAcceptableOrUnknown(
          data['epg_channel_id']!,
          _epgChannelIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('stop')) {
      context.handle(
        _stopMeta,
        stop.isAcceptableOrUnknown(data['stop']!, _stopMeta),
      );
    } else if (isInserting) {
      context.missing(_stopMeta);
    }
    if (data.containsKey('fired')) {
      context.handle(
        _firedMeta,
        fired.isAcceptableOrUnknown(data['fired']!, _firedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {playlistId, channelId, start},
  ];
  @override
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      channelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_name'],
      )!,
      epgChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epg_channel_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start'],
      )!,
      stop: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stop'],
      )!,
      fired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fired'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  final int id;
  final int playlistId;

  /// Provider channel id.
  final String channelId;
  final String channelName;
  final String? epgChannelId;
  final String title;

  /// UTC epoch ms.
  final int start;
  final int stop;
  final bool fired;
  final DateTime createdAt;
  const ReminderRow({
    required this.id,
    required this.playlistId,
    required this.channelId,
    required this.channelName,
    this.epgChannelId,
    required this.title,
    required this.start,
    required this.stop,
    required this.fired,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['channel_id'] = Variable<String>(channelId);
    map['channel_name'] = Variable<String>(channelName);
    if (!nullToAbsent || epgChannelId != null) {
      map['epg_channel_id'] = Variable<String>(epgChannelId);
    }
    map['title'] = Variable<String>(title);
    map['start'] = Variable<int>(start);
    map['stop'] = Variable<int>(stop);
    map['fired'] = Variable<bool>(fired);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      channelId: Value(channelId),
      channelName: Value(channelName),
      epgChannelId: epgChannelId == null && nullToAbsent
          ? const Value.absent()
          : Value(epgChannelId),
      title: Value(title),
      start: Value(start),
      stop: Value(stop),
      fired: Value(fired),
      createdAt: Value(createdAt),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      channelName: serializer.fromJson<String>(json['channelName']),
      epgChannelId: serializer.fromJson<String?>(json['epgChannelId']),
      title: serializer.fromJson<String>(json['title']),
      start: serializer.fromJson<int>(json['start']),
      stop: serializer.fromJson<int>(json['stop']),
      fired: serializer.fromJson<bool>(json['fired']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'channelId': serializer.toJson<String>(channelId),
      'channelName': serializer.toJson<String>(channelName),
      'epgChannelId': serializer.toJson<String?>(epgChannelId),
      'title': serializer.toJson<String>(title),
      'start': serializer.toJson<int>(start),
      'stop': serializer.toJson<int>(stop),
      'fired': serializer.toJson<bool>(fired),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReminderRow copyWith({
    int? id,
    int? playlistId,
    String? channelId,
    String? channelName,
    Value<String?> epgChannelId = const Value.absent(),
    String? title,
    int? start,
    int? stop,
    bool? fired,
    DateTime? createdAt,
  }) => ReminderRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    channelId: channelId ?? this.channelId,
    channelName: channelName ?? this.channelName,
    epgChannelId: epgChannelId.present ? epgChannelId.value : this.epgChannelId,
    title: title ?? this.title,
    start: start ?? this.start,
    stop: stop ?? this.stop,
    fired: fired ?? this.fired,
    createdAt: createdAt ?? this.createdAt,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      channelName: data.channelName.present
          ? data.channelName.value
          : this.channelName,
      epgChannelId: data.epgChannelId.present
          ? data.epgChannelId.value
          : this.epgChannelId,
      title: data.title.present ? data.title.value : this.title,
      start: data.start.present ? data.start.value : this.start,
      stop: data.stop.present ? data.stop.value : this.stop,
      fired: data.fired.present ? data.fired.value : this.fired,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('channelId: $channelId, ')
          ..write('channelName: $channelName, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('title: $title, ')
          ..write('start: $start, ')
          ..write('stop: $stop, ')
          ..write('fired: $fired, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    channelId,
    channelName,
    epgChannelId,
    title,
    start,
    stop,
    fired,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.channelId == this.channelId &&
          other.channelName == this.channelName &&
          other.epgChannelId == this.epgChannelId &&
          other.title == this.title &&
          other.start == this.start &&
          other.stop == this.stop &&
          other.fired == this.fired &&
          other.createdAt == this.createdAt);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> channelId;
  final Value<String> channelName;
  final Value<String?> epgChannelId;
  final Value<String> title;
  final Value<int> start;
  final Value<int> stop;
  final Value<bool> fired;
  final Value<DateTime> createdAt;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.channelName = const Value.absent(),
    this.epgChannelId = const Value.absent(),
    this.title = const Value.absent(),
    this.start = const Value.absent(),
    this.stop = const Value.absent(),
    this.fired = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RemindersCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String channelId,
    required String channelName,
    this.epgChannelId = const Value.absent(),
    required String title,
    required int start,
    required int stop,
    this.fired = const Value.absent(),
    required DateTime createdAt,
  }) : playlistId = Value(playlistId),
       channelId = Value(channelId),
       channelName = Value(channelName),
       title = Value(title),
       start = Value(start),
       stop = Value(stop),
       createdAt = Value(createdAt);
  static Insertable<ReminderRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? channelId,
    Expression<String>? channelName,
    Expression<String>? epgChannelId,
    Expression<String>? title,
    Expression<int>? start,
    Expression<int>? stop,
    Expression<bool>? fired,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (channelId != null) 'channel_id': channelId,
      if (channelName != null) 'channel_name': channelName,
      if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      if (title != null) 'title': title,
      if (start != null) 'start': start,
      if (stop != null) 'stop': stop,
      if (fired != null) 'fired': fired,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RemindersCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? channelId,
    Value<String>? channelName,
    Value<String?>? epgChannelId,
    Value<String>? title,
    Value<int>? start,
    Value<int>? stop,
    Value<bool>? fired,
    Value<DateTime>? createdAt,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      title: title ?? this.title,
      start: start ?? this.start,
      stop: stop ?? this.stop,
      fired: fired ?? this.fired,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (channelName.present) {
      map['channel_name'] = Variable<String>(channelName.value);
    }
    if (epgChannelId.present) {
      map['epg_channel_id'] = Variable<String>(epgChannelId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (start.present) {
      map['start'] = Variable<int>(start.value);
    }
    if (stop.present) {
      map['stop'] = Variable<int>(stop.value);
    }
    if (fired.present) {
      map['fired'] = Variable<bool>(fired.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('channelId: $channelId, ')
          ..write('channelName: $channelName, ')
          ..write('epgChannelId: $epgChannelId, ')
          ..write('title: $title, ')
          ..write('start: $start, ')
          ..write('stop: $stop, ')
          ..write('fired: $fired, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, DownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemType, int> itemType =
      GeneratedColumn<int>(
        'item_type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ItemType>($DownloadsTable.$converteritemType);
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DownloadStatus>($DownloadsTable.$converterstatus);
  static const VerificationMeta _bytesTotalMeta = const VerificationMeta(
    'bytesTotal',
  );
  @override
  late final GeneratedColumn<int> bytesTotal = GeneratedColumn<int>(
    'bytes_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bytesDoneMeta = const VerificationMeta(
    'bytesDone',
  );
  @override
  late final GeneratedColumn<int> bytesDone = GeneratedColumn<int>(
    'bytes_done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    itemType,
    providerId,
    title,
    url,
    filePath,
    status,
    bytesTotal,
    bytesDone,
    error,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('bytes_total')) {
      context.handle(
        _bytesTotalMeta,
        bytesTotal.isAcceptableOrUnknown(data['bytes_total']!, _bytesTotalMeta),
      );
    }
    if (data.containsKey('bytes_done')) {
      context.handle(
        _bytesDoneMeta,
        bytesDone.isAcceptableOrUnknown(data['bytes_done']!, _bytesDoneMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      ),
      itemType: $DownloadsTable.$converteritemType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}item_type'],
        )!,
      ),
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      status: $DownloadsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      bytesTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_total'],
      )!,
      bytesDone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_done'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemType, int, int> $converteritemType =
      const EnumIndexConverter<ItemType>(ItemType.values);
  static JsonTypeConverter2<DownloadStatus, int, int> $converterstatus =
      const EnumIndexConverter<DownloadStatus>(DownloadStatus.values);
}

class DownloadRow extends DataClass implements Insertable<DownloadRow> {
  final int id;
  final int? playlistId;
  final ItemType itemType;
  final String providerId;
  final String title;
  final String url;
  final String filePath;
  final DownloadStatus status;
  final int bytesTotal;
  final int bytesDone;
  final String? error;
  final DateTime createdAt;
  const DownloadRow({
    required this.id,
    this.playlistId,
    required this.itemType,
    required this.providerId,
    required this.title,
    required this.url,
    required this.filePath,
    required this.status,
    required this.bytesTotal,
    required this.bytesDone,
    this.error,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || playlistId != null) {
      map['playlist_id'] = Variable<int>(playlistId);
    }
    {
      map['item_type'] = Variable<int>(
        $DownloadsTable.$converteritemType.toSql(itemType),
      );
    }
    map['provider_id'] = Variable<String>(providerId);
    map['title'] = Variable<String>(title);
    map['url'] = Variable<String>(url);
    map['file_path'] = Variable<String>(filePath);
    {
      map['status'] = Variable<int>(
        $DownloadsTable.$converterstatus.toSql(status),
      );
    }
    map['bytes_total'] = Variable<int>(bytesTotal);
    map['bytes_done'] = Variable<int>(bytesDone);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      id: Value(id),
      playlistId: playlistId == null && nullToAbsent
          ? const Value.absent()
          : Value(playlistId),
      itemType: Value(itemType),
      providerId: Value(providerId),
      title: Value(title),
      url: Value(url),
      filePath: Value(filePath),
      status: Value(status),
      bytesTotal: Value(bytesTotal),
      bytesDone: Value(bytesDone),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
    );
  }

  factory DownloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int?>(json['playlistId']),
      itemType: $DownloadsTable.$converteritemType.fromJson(
        serializer.fromJson<int>(json['itemType']),
      ),
      providerId: serializer.fromJson<String>(json['providerId']),
      title: serializer.fromJson<String>(json['title']),
      url: serializer.fromJson<String>(json['url']),
      filePath: serializer.fromJson<String>(json['filePath']),
      status: $DownloadsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      bytesTotal: serializer.fromJson<int>(json['bytesTotal']),
      bytesDone: serializer.fromJson<int>(json['bytesDone']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int?>(playlistId),
      'itemType': serializer.toJson<int>(
        $DownloadsTable.$converteritemType.toJson(itemType),
      ),
      'providerId': serializer.toJson<String>(providerId),
      'title': serializer.toJson<String>(title),
      'url': serializer.toJson<String>(url),
      'filePath': serializer.toJson<String>(filePath),
      'status': serializer.toJson<int>(
        $DownloadsTable.$converterstatus.toJson(status),
      ),
      'bytesTotal': serializer.toJson<int>(bytesTotal),
      'bytesDone': serializer.toJson<int>(bytesDone),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DownloadRow copyWith({
    int? id,
    Value<int?> playlistId = const Value.absent(),
    ItemType? itemType,
    String? providerId,
    String? title,
    String? url,
    String? filePath,
    DownloadStatus? status,
    int? bytesTotal,
    int? bytesDone,
    Value<String?> error = const Value.absent(),
    DateTime? createdAt,
  }) => DownloadRow(
    id: id ?? this.id,
    playlistId: playlistId.present ? playlistId.value : this.playlistId,
    itemType: itemType ?? this.itemType,
    providerId: providerId ?? this.providerId,
    title: title ?? this.title,
    url: url ?? this.url,
    filePath: filePath ?? this.filePath,
    status: status ?? this.status,
    bytesTotal: bytesTotal ?? this.bytesTotal,
    bytesDone: bytesDone ?? this.bytesDone,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
  );
  DownloadRow copyWithCompanion(DownloadsCompanion data) {
    return DownloadRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      title: data.title.present ? data.title.value : this.title,
      url: data.url.present ? data.url.value : this.url,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      status: data.status.present ? data.status.value : this.status,
      bytesTotal: data.bytesTotal.present
          ? data.bytesTotal.value
          : this.bytesTotal,
      bytesDone: data.bytesDone.present ? data.bytesDone.value : this.bytesDone,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('itemType: $itemType, ')
          ..write('providerId: $providerId, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('filePath: $filePath, ')
          ..write('status: $status, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('bytesDone: $bytesDone, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    itemType,
    providerId,
    title,
    url,
    filePath,
    status,
    bytesTotal,
    bytesDone,
    error,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.itemType == this.itemType &&
          other.providerId == this.providerId &&
          other.title == this.title &&
          other.url == this.url &&
          other.filePath == this.filePath &&
          other.status == this.status &&
          other.bytesTotal == this.bytesTotal &&
          other.bytesDone == this.bytesDone &&
          other.error == this.error &&
          other.createdAt == this.createdAt);
}

class DownloadsCompanion extends UpdateCompanion<DownloadRow> {
  final Value<int> id;
  final Value<int?> playlistId;
  final Value<ItemType> itemType;
  final Value<String> providerId;
  final Value<String> title;
  final Value<String> url;
  final Value<String> filePath;
  final Value<DownloadStatus> status;
  final Value<int> bytesTotal;
  final Value<int> bytesDone;
  final Value<String?> error;
  final Value<DateTime> createdAt;
  const DownloadsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.providerId = const Value.absent(),
    this.title = const Value.absent(),
    this.url = const Value.absent(),
    this.filePath = const Value.absent(),
    this.status = const Value.absent(),
    this.bytesTotal = const Value.absent(),
    this.bytesDone = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DownloadsCompanion.insert({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    required ItemType itemType,
    required String providerId,
    required String title,
    required String url,
    required String filePath,
    required DownloadStatus status,
    this.bytesTotal = const Value.absent(),
    this.bytesDone = const Value.absent(),
    this.error = const Value.absent(),
    required DateTime createdAt,
  }) : itemType = Value(itemType),
       providerId = Value(providerId),
       title = Value(title),
       url = Value(url),
       filePath = Value(filePath),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<DownloadRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<int>? itemType,
    Expression<String>? providerId,
    Expression<String>? title,
    Expression<String>? url,
    Expression<String>? filePath,
    Expression<int>? status,
    Expression<int>? bytesTotal,
    Expression<int>? bytesDone,
    Expression<String>? error,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (itemType != null) 'item_type': itemType,
      if (providerId != null) 'provider_id': providerId,
      if (title != null) 'title': title,
      if (url != null) 'url': url,
      if (filePath != null) 'file_path': filePath,
      if (status != null) 'status': status,
      if (bytesTotal != null) 'bytes_total': bytesTotal,
      if (bytesDone != null) 'bytes_done': bytesDone,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DownloadsCompanion copyWith({
    Value<int>? id,
    Value<int?>? playlistId,
    Value<ItemType>? itemType,
    Value<String>? providerId,
    Value<String>? title,
    Value<String>? url,
    Value<String>? filePath,
    Value<DownloadStatus>? status,
    Value<int>? bytesTotal,
    Value<int>? bytesDone,
    Value<String?>? error,
    Value<DateTime>? createdAt,
  }) {
    return DownloadsCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      itemType: itemType ?? this.itemType,
      providerId: providerId ?? this.providerId,
      title: title ?? this.title,
      url: url ?? this.url,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      bytesDone: bytesDone ?? this.bytesDone,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<int>(
        $DownloadsTable.$converteritemType.toSql(itemType.value),
      );
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $DownloadsTable.$converterstatus.toSql(status.value),
      );
    }
    if (bytesTotal.present) {
      map['bytes_total'] = Variable<int>(bytesTotal.value);
    }
    if (bytesDone.present) {
      map['bytes_done'] = Variable<int>(bytesDone.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('itemType: $itemType, ')
          ..write('providerId: $providerId, ')
          ..write('title: $title, ')
          ..write('url: $url, ')
          ..write('filePath: $filePath, ')
          ..write('status: $status, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('bytesDone: $bytesDone, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RecordingsTable extends Recordings
    with TableInfo<$RecordingsTable, RecordingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelNameMeta = const VerificationMeta(
    'channelName',
  );
  @override
  late final GeneratedColumn<String> channelName = GeneratedColumn<String>(
    'channel_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
    'ends_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DownloadStatus>($RecordingsTable.$converterstatus);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    channelId,
    channelName,
    title,
    filePath,
    startedAt,
    endsAt,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('channel_name')) {
      context.handle(
        _channelNameMeta,
        channelName.isAcceptableOrUnknown(
          data['channel_name']!,
          _channelNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_channelNameMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      ),
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      channelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_name'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_at'],
      ),
      status: $RecordingsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
    );
  }

  @override
  $RecordingsTable createAlias(String alias) {
    return $RecordingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadStatus, int, int> $converterstatus =
      const EnumIndexConverter<DownloadStatus>(DownloadStatus.values);
}

class RecordingRow extends DataClass implements Insertable<RecordingRow> {
  final int id;
  final int? playlistId;
  final String channelId;
  final String channelName;
  final String title;
  final String filePath;
  final DateTime startedAt;
  final DateTime? endsAt;
  final DownloadStatus status;
  const RecordingRow({
    required this.id,
    this.playlistId,
    required this.channelId,
    required this.channelName,
    required this.title,
    required this.filePath,
    required this.startedAt,
    this.endsAt,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || playlistId != null) {
      map['playlist_id'] = Variable<int>(playlistId);
    }
    map['channel_id'] = Variable<String>(channelId);
    map['channel_name'] = Variable<String>(channelName);
    map['title'] = Variable<String>(title);
    map['file_path'] = Variable<String>(filePath);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endsAt != null) {
      map['ends_at'] = Variable<DateTime>(endsAt);
    }
    {
      map['status'] = Variable<int>(
        $RecordingsTable.$converterstatus.toSql(status),
      );
    }
    return map;
  }

  RecordingsCompanion toCompanion(bool nullToAbsent) {
    return RecordingsCompanion(
      id: Value(id),
      playlistId: playlistId == null && nullToAbsent
          ? const Value.absent()
          : Value(playlistId),
      channelId: Value(channelId),
      channelName: Value(channelName),
      title: Value(title),
      filePath: Value(filePath),
      startedAt: Value(startedAt),
      endsAt: endsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endsAt),
      status: Value(status),
    );
  }

  factory RecordingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordingRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int?>(json['playlistId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      channelName: serializer.fromJson<String>(json['channelName']),
      title: serializer.fromJson<String>(json['title']),
      filePath: serializer.fromJson<String>(json['filePath']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endsAt: serializer.fromJson<DateTime?>(json['endsAt']),
      status: $RecordingsTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int?>(playlistId),
      'channelId': serializer.toJson<String>(channelId),
      'channelName': serializer.toJson<String>(channelName),
      'title': serializer.toJson<String>(title),
      'filePath': serializer.toJson<String>(filePath),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endsAt': serializer.toJson<DateTime?>(endsAt),
      'status': serializer.toJson<int>(
        $RecordingsTable.$converterstatus.toJson(status),
      ),
    };
  }

  RecordingRow copyWith({
    int? id,
    Value<int?> playlistId = const Value.absent(),
    String? channelId,
    String? channelName,
    String? title,
    String? filePath,
    DateTime? startedAt,
    Value<DateTime?> endsAt = const Value.absent(),
    DownloadStatus? status,
  }) => RecordingRow(
    id: id ?? this.id,
    playlistId: playlistId.present ? playlistId.value : this.playlistId,
    channelId: channelId ?? this.channelId,
    channelName: channelName ?? this.channelName,
    title: title ?? this.title,
    filePath: filePath ?? this.filePath,
    startedAt: startedAt ?? this.startedAt,
    endsAt: endsAt.present ? endsAt.value : this.endsAt,
    status: status ?? this.status,
  );
  RecordingRow copyWithCompanion(RecordingsCompanion data) {
    return RecordingRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      channelName: data.channelName.present
          ? data.channelName.value
          : this.channelName,
      title: data.title.present ? data.title.value : this.title,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordingRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('channelId: $channelId, ')
          ..write('channelName: $channelName, ')
          ..write('title: $title, ')
          ..write('filePath: $filePath, ')
          ..write('startedAt: $startedAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    channelId,
    channelName,
    title,
    filePath,
    startedAt,
    endsAt,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordingRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.channelId == this.channelId &&
          other.channelName == this.channelName &&
          other.title == this.title &&
          other.filePath == this.filePath &&
          other.startedAt == this.startedAt &&
          other.endsAt == this.endsAt &&
          other.status == this.status);
}

class RecordingsCompanion extends UpdateCompanion<RecordingRow> {
  final Value<int> id;
  final Value<int?> playlistId;
  final Value<String> channelId;
  final Value<String> channelName;
  final Value<String> title;
  final Value<String> filePath;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endsAt;
  final Value<DownloadStatus> status;
  const RecordingsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.channelName = const Value.absent(),
    this.title = const Value.absent(),
    this.filePath = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.status = const Value.absent(),
  });
  RecordingsCompanion.insert({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    required String channelId,
    required String channelName,
    required String title,
    required String filePath,
    required DateTime startedAt,
    this.endsAt = const Value.absent(),
    required DownloadStatus status,
  }) : channelId = Value(channelId),
       channelName = Value(channelName),
       title = Value(title),
       filePath = Value(filePath),
       startedAt = Value(startedAt),
       status = Value(status);
  static Insertable<RecordingRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? channelId,
    Expression<String>? channelName,
    Expression<String>? title,
    Expression<String>? filePath,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endsAt,
    Expression<int>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (channelId != null) 'channel_id': channelId,
      if (channelName != null) 'channel_name': channelName,
      if (title != null) 'title': title,
      if (filePath != null) 'file_path': filePath,
      if (startedAt != null) 'started_at': startedAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (status != null) 'status': status,
    });
  }

  RecordingsCompanion copyWith({
    Value<int>? id,
    Value<int?>? playlistId,
    Value<String>? channelId,
    Value<String>? channelName,
    Value<String>? title,
    Value<String>? filePath,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endsAt,
    Value<DownloadStatus>? status,
  }) {
    return RecordingsCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      startedAt: startedAt ?? this.startedAt,
      endsAt: endsAt ?? this.endsAt,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (channelName.present) {
      map['channel_name'] = Variable<String>(channelName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $RecordingsTable.$converterstatus.toSql(status.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingsCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('channelId: $channelId, ')
          ..write('channelName: $channelName, ')
          ..write('title: $title, ')
          ..write('filePath: $filePath, ')
          ..write('startedAt: $startedAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $TmdbCacheTable extends TmdbCache
    with TableInfo<$TmdbCacheTable, TmdbCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TmdbCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cacheKey, json, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tmdb_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<TmdbCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  TmdbCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TmdbCacheRow(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $TmdbCacheTable createAlias(String alias) {
    return $TmdbCacheTable(attachedDatabase, alias);
  }
}

class TmdbCacheRow extends DataClass implements Insertable<TmdbCacheRow> {
  final String cacheKey;
  final String json;
  final DateTime fetchedAt;
  const TmdbCacheRow({
    required this.cacheKey,
    required this.json,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['json'] = Variable<String>(json);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  TmdbCacheCompanion toCompanion(bool nullToAbsent) {
    return TmdbCacheCompanion(
      cacheKey: Value(cacheKey),
      json: Value(json),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory TmdbCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TmdbCacheRow(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      json: serializer.fromJson<String>(json['json']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'json': serializer.toJson<String>(json),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  TmdbCacheRow copyWith({
    String? cacheKey,
    String? json,
    DateTime? fetchedAt,
  }) => TmdbCacheRow(
    cacheKey: cacheKey ?? this.cacheKey,
    json: json ?? this.json,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  TmdbCacheRow copyWithCompanion(TmdbCacheCompanion data) {
    return TmdbCacheRow(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      json: data.json.present ? data.json.value : this.json,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TmdbCacheRow(')
          ..write('cacheKey: $cacheKey, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, json, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TmdbCacheRow &&
          other.cacheKey == this.cacheKey &&
          other.json == this.json &&
          other.fetchedAt == this.fetchedAt);
}

class TmdbCacheCompanion extends UpdateCompanion<TmdbCacheRow> {
  final Value<String> cacheKey;
  final Value<String> json;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const TmdbCacheCompanion({
    this.cacheKey = const Value.absent(),
    this.json = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TmdbCacheCompanion.insert({
    required String cacheKey,
    required String json,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       json = Value(json),
       fetchedAt = Value(fetchedAt);
  static Insertable<TmdbCacheRow> custom({
    Expression<String>? cacheKey,
    Expression<String>? json,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (json != null) 'json': json,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TmdbCacheCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? json,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return TmdbCacheCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      json: json ?? this.json,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TmdbCacheCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [scope, key, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String scope;
  final String key;
  final String json;
  const SettingRow({
    required this.scope,
    required this.key,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      scope: Value(scope),
      key: Value(key),
      json: Value(json),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      scope: serializer.fromJson<String>(json['scope']),
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
    };
  }

  SettingRow copyWith({String? scope, String? key, String? json}) => SettingRow(
    scope: scope ?? this.scope,
    key: key ?? this.key,
    json: json ?? this.json,
  );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, key, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.scope == this.scope &&
          other.key == this.key &&
          other.json == this.json);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> scope;
  final Value<String> key;
  final Value<String> json;
  final Value<int> rowid;
  const SettingsCompanion({
    this.scope = const Value.absent(),
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String scope,
    required String key,
    required String json,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       key = Value(key),
       json = Value(json);
  static Insertable<SettingRow> custom({
    Expression<String>? scope,
    Expression<String>? key,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? scope,
    Value<String>? key,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      scope: scope ?? this.scope,
      key: key ?? this.key,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final SearchIndex searchIndex = SearchIndex(this);
  late final ProgrammeSearch programmeSearch = ProgrammeSearch(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final $MoviesTable movies = $MoviesTable(this);
  late final $SeriesTable series = $SeriesTable(this);
  late final $SeasonsTable seasons = $SeasonsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $EpgChannelsTable epgChannels = $EpgChannelsTable(this);
  late final $ProgrammesTable programmes = $ProgrammesTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $FavoriteTagsTable favoriteTags = $FavoriteTagsTable(this);
  late final $FavoriteTagLinksTable favoriteTagLinks = $FavoriteTagLinksTable(
    this,
  );
  late final $WatchStatesTable watchStates = $WatchStatesTable(this);
  late final $LastWatchedLiveTable lastWatchedLive = $LastWatchedLiveTable(
    this,
  );
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $RecordingsTable recordings = $RecordingsTable(this);
  late final $TmdbCacheTable tmdbCache = $TmdbCacheTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index idxCategoriesPlKind = Index(
    'idx_categories_pl_kind',
    'CREATE INDEX idx_categories_pl_kind ON categories (playlist_id, kind)',
  );
  late final Index idxChannelsPlCat = Index(
    'idx_channels_pl_cat',
    'CREATE INDEX idx_channels_pl_cat ON channels (playlist_id, category_id)',
  );
  late final Index idxChannelsPlNum = Index(
    'idx_channels_pl_num',
    'CREATE INDEX idx_channels_pl_num ON channels (playlist_id, num)',
  );
  late final Index idxMoviesPlCat = Index(
    'idx_movies_pl_cat',
    'CREATE INDEX idx_movies_pl_cat ON movies (playlist_id, category_id)',
  );
  late final Index idxMoviesPlAdded = Index(
    'idx_movies_pl_added',
    'CREATE INDEX idx_movies_pl_added ON movies (playlist_id, added)',
  );
  late final Index idxSeriesPlCat = Index(
    'idx_series_pl_cat',
    'CREATE INDEX idx_series_pl_cat ON series (playlist_id, category_id)',
  );
  late final Index idxEpisodesSeries = Index(
    'idx_episodes_series',
    'CREATE INDEX idx_episodes_series ON episodes (playlist_id, series_id)',
  );
  late final Index idxProgrammesChannelStart = Index(
    'idx_programmes_channel_start',
    'CREATE INDEX idx_programmes_channel_start ON programmes (playlist_id, epg_channel_id, start)',
  );
  late final Index idxProgrammesStop = Index(
    'idx_programmes_stop',
    'CREATE INDEX idx_programmes_stop ON programmes (playlist_id, stop)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    searchIndex,
    programmeSearch,
    playlists,
    categories,
    channels,
    movies,
    series,
    seasons,
    episodes,
    epgChannels,
    programmes,
    favorites,
    favoriteTags,
    favoriteTagLinks,
    watchStates,
    lastWatchedLive,
    reminders,
    downloads,
    recordings,
    tmdbCache,
    settings,
    idxCategoriesPlKind,
    idxChannelsPlCat,
    idxChannelsPlNum,
    idxMoviesPlCat,
    idxMoviesPlAdded,
    idxSeriesPlCat,
    idxEpisodesSeries,
    idxProgrammesChannelStart,
    idxProgrammesStop,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('categories', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('channels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('movies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('series', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('seasons', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('episodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('epg_channels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('programmes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorites', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorite_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'favorites',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorite_tag_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'favorite_tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorite_tag_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('watch_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('last_watched_live', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminders', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $SearchIndexCreateCompanionBuilder = SearchIndexCompanion Function({
  required String normalized,
  required String title,
  required String kind,
  required String refId,
  required String playlistId,
  Value<int> rowid,
});
typedef $SearchIndexUpdateCompanionBuilder = SearchIndexCompanion Function({
  Value<String> normalized,
  Value<String> title,
  Value<String> kind,
  Value<String> refId,
  Value<String> playlistId,
  Value<int> rowid,
});

class $SearchIndexFilterComposer extends Composer<_$AppDatabase, SearchIndex> {
  $SearchIndexFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );
}

class $SearchIndexOrderingComposer
    extends Composer<_$AppDatabase, SearchIndex> {
  $SearchIndexOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SearchIndexAnnotationComposer
    extends Composer<_$AppDatabase, SearchIndex> {
  $SearchIndexAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );
}

class $SearchIndexTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SearchIndex,
          SearchIndexData,
          $SearchIndexFilterComposer,
          $SearchIndexOrderingComposer,
          $SearchIndexAnnotationComposer,
          $SearchIndexCreateCompanionBuilder,
          $SearchIndexUpdateCompanionBuilder,
          (
            SearchIndexData,
            BaseReferences<_$AppDatabase, SearchIndex, SearchIndexData>,
          ),
          SearchIndexData,
          PrefetchHooks Function()
        > {
  $SearchIndexTableManager(_$AppDatabase db, SearchIndex table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SearchIndexFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SearchIndexOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SearchIndexAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> normalized = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> refId = const Value.absent(),
                Value<String> playlistId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchIndexCompanion(
                normalized: normalized,
                title: title,
                kind: kind,
                refId: refId,
                playlistId: playlistId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String normalized,
                required String title,
                required String kind,
                required String refId,
                required String playlistId,
                Value<int> rowid = const Value.absent(),
              }) => SearchIndexCompanion.insert(
                normalized: normalized,
                title: title,
                kind: kind,
                refId: refId,
                playlistId: playlistId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SearchIndex, SearchIndexData>(table),
                  BaseReferences<_$AppDatabase, SearchIndex, SearchIndexData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SearchIndexProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SearchIndex,
      SearchIndexData,
      $SearchIndexFilterComposer,
      $SearchIndexOrderingComposer,
      $SearchIndexAnnotationComposer,
      $SearchIndexCreateCompanionBuilder,
      $SearchIndexUpdateCompanionBuilder,
      (
        SearchIndexData,
        BaseReferences<_$AppDatabase, SearchIndex, SearchIndexData>,
      ),
      SearchIndexData,
      PrefetchHooks Function()
    >;
typedef $ProgrammeSearchCreateCompanionBuilder =
    ProgrammeSearchCompanion Function({
      required String normalized,
      required String programmeId,
      required String playlistId,
      Value<int> rowid,
    });
typedef $ProgrammeSearchUpdateCompanionBuilder =
    ProgrammeSearchCompanion Function({
      Value<String> normalized,
      Value<String> programmeId,
      Value<String> playlistId,
      Value<int> rowid,
    });

class $ProgrammeSearchFilterComposer
    extends Composer<_$AppDatabase, ProgrammeSearch> {
  $ProgrammeSearchFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get programmeId => $composableBuilder(
    column: $table.programmeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );
}

class $ProgrammeSearchOrderingComposer
    extends Composer<_$AppDatabase, ProgrammeSearch> {
  $ProgrammeSearchOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get programmeId => $composableBuilder(
    column: $table.programmeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ProgrammeSearchAnnotationComposer
    extends Composer<_$AppDatabase, ProgrammeSearch> {
  $ProgrammeSearchAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get programmeId => $composableBuilder(
    column: $table.programmeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );
}

class $ProgrammeSearchTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          ProgrammeSearch,
          ProgrammeSearchData,
          $ProgrammeSearchFilterComposer,
          $ProgrammeSearchOrderingComposer,
          $ProgrammeSearchAnnotationComposer,
          $ProgrammeSearchCreateCompanionBuilder,
          $ProgrammeSearchUpdateCompanionBuilder,
          (
            ProgrammeSearchData,
            BaseReferences<_$AppDatabase, ProgrammeSearch, ProgrammeSearchData>,
          ),
          ProgrammeSearchData,
          PrefetchHooks Function()
        > {
  $ProgrammeSearchTableManager(_$AppDatabase db, ProgrammeSearch table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ProgrammeSearchFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ProgrammeSearchOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ProgrammeSearchAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> normalized = const Value.absent(),
                Value<String> programmeId = const Value.absent(),
                Value<String> playlistId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgrammeSearchCompanion(
                normalized: normalized,
                programmeId: programmeId,
                playlistId: playlistId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String normalized,
                required String programmeId,
                required String playlistId,
                Value<int> rowid = const Value.absent(),
              }) => ProgrammeSearchCompanion.insert(
                normalized: normalized,
                programmeId: programmeId,
                playlistId: playlistId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ProgrammeSearch, ProgrammeSearchData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    ProgrammeSearch,
                    ProgrammeSearchData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ProgrammeSearchProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      ProgrammeSearch,
      ProgrammeSearchData,
      $ProgrammeSearchFilterComposer,
      $ProgrammeSearchOrderingComposer,
      $ProgrammeSearchAnnotationComposer,
      $ProgrammeSearchCreateCompanionBuilder,
      $ProgrammeSearchUpdateCompanionBuilder,
      (
        ProgrammeSearchData,
        BaseReferences<_$AppDatabase, ProgrammeSearch, ProgrammeSearchData>,
      ),
      ProgrammeSearchData,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  required PlaylistType type,
  Value<String?> server,
  Value<String?> username,
  Value<String?> m3uUrl,
  Value<String?> epgUrl,
  Value<int> epgShiftHours,
  Value<int> reloadFrequencyHours,
  Value<String?> userAgent,
  Value<String?> avatarId,
  Value<bool> hasAccessPin,
  Value<int> sortIndex,
  required DateTime createdAt,
  Value<DateTime?> lastReloadAt,
  Value<DateTime?> lastEpgReloadAt,
  Value<String?> accountJson,
  Value<String?> m3uHeaderJson,
  Value<int> liveCount,
  Value<int> movieCount,
  Value<int> seriesCount,
  Value<int> programmeCount,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<PlaylistType> type,
  Value<String?> server,
  Value<String?> username,
  Value<String?> m3uUrl,
  Value<String?> epgUrl,
  Value<int> epgShiftHours,
  Value<int> reloadFrequencyHours,
  Value<String?> userAgent,
  Value<String?> avatarId,
  Value<bool> hasAccessPin,
  Value<int> sortIndex,
  Value<DateTime> createdAt,
  Value<DateTime?> lastReloadAt,
  Value<DateTime?> lastEpgReloadAt,
  Value<String?> accountJson,
  Value<String?> m3uHeaderJson,
  Value<int> liveCount,
  Value<int> movieCount,
  Value<int> seriesCount,
  Value<int> programmeCount,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistRow> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CategoriesTable, List<CategoryRow>>
  _categoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.categories,
    aliasName: 'playlists__id__categories__playlist_id',
  );

  $$CategoriesTableProcessedTableManager get categoriesRefs {
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_categoriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ChannelsTable, List<ChannelRow>>
  _channelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.channels,
    aliasName: 'playlists__id__channels__playlist_id',
  );

  $$ChannelsTableProcessedTableManager get channelsRefs {
    final manager = $$ChannelsTableTableManager(
      $_db,
      $_db.channels,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_channelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MoviesTable, List<MovieRow>> _moviesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.movies,
    aliasName: 'playlists__id__movies__playlist_id',
  );

  $$MoviesTableProcessedTableManager get moviesRefs {
    final manager = $$MoviesTableTableManager(
      $_db,
      $_db.movies,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_moviesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SeriesTable, List<SeriesRow>> _seriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.series,
    aliasName: 'playlists__id__series__playlist_id',
  );

  $$SeriesTableProcessedTableManager get seriesRefs {
    final manager = $$SeriesTableTableManager(
      $_db,
      $_db.series,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_seriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SeasonsTable, List<SeasonRow>> _seasonsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.seasons,
    aliasName: 'playlists__id__seasons__playlist_id',
  );

  $$SeasonsTableProcessedTableManager get seasonsRefs {
    final manager = $$SeasonsTableTableManager(
      $_db,
      $_db.seasons,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_seasonsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpisodesTable, List<EpisodeRow>>
  _episodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.episodes,
    aliasName: 'playlists__id__episodes__playlist_id',
  );

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EpgChannelsTable, List<EpgChannelRow>>
  _epgChannelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.epgChannels,
    aliasName: 'playlists__id__epg_channels__playlist_id',
  );

  $$EpgChannelsTableProcessedTableManager get epgChannelsRefs {
    final manager = $$EpgChannelsTableTableManager(
      $_db,
      $_db.epgChannels,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_epgChannelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProgrammesTable, List<ProgrammeRow>>
  _programmesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.programmes,
    aliasName: 'playlists__id__programmes__playlist_id',
  );

  $$ProgrammesTableProcessedTableManager get programmesRefs {
    final manager = $$ProgrammesTableTableManager(
      $_db,
      $_db.programmes,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_programmesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FavoritesTable, List<FavoriteRow>>
  _favoritesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favorites,
    aliasName: 'playlists__id__favorites__playlist_id',
  );

  $$FavoritesTableProcessedTableManager get favoritesRefs {
    final manager = $$FavoritesTableTableManager(
      $_db,
      $_db.favorites,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoritesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FavoriteTagsTable, List<FavoriteTagRow>>
  _favoriteTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favoriteTags,
    aliasName: 'playlists__id__favorite_tags__playlist_id',
  );

  $$FavoriteTagsTableProcessedTableManager get favoriteTagsRefs {
    final manager = $$FavoriteTagsTableTableManager(
      $_db,
      $_db.favoriteTags,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoriteTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WatchStatesTable, List<WatchStateRow>>
  _watchStatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.watchStates,
    aliasName: 'playlists__id__watch_states__playlist_id',
  );

  $$WatchStatesTableProcessedTableManager get watchStatesRefs {
    final manager = $$WatchStatesTableTableManager(
      $_db,
      $_db.watchStates,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_watchStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LastWatchedLiveTable, List<LastWatchedLiveRow>>
  _lastWatchedLiveRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.lastWatchedLive,
    aliasName: 'playlists__id__last_watched_live__playlist_id',
  );

  $$LastWatchedLiveTableProcessedTableManager get lastWatchedLiveRefs {
    final manager = $$LastWatchedLiveTableTableManager(
      $_db,
      $_db.lastWatchedLive,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _lastWatchedLiveRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: 'playlists__id__reminders__playlist_id',
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PlaylistType, PlaylistType, int> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get server => $composableBuilder(
    column: $table.server,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get m3uUrl => $composableBuilder(
    column: $table.m3uUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgUrl => $composableBuilder(
    column: $table.epgUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get epgShiftHours => $composableBuilder(
    column: $table.epgShiftHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reloadFrequencyHours => $composableBuilder(
    column: $table.reloadFrequencyHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userAgent => $composableBuilder(
    column: $table.userAgent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarId => $composableBuilder(
    column: $table.avatarId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasAccessPin => $composableBuilder(
    column: $table.hasAccessPin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReloadAt => $composableBuilder(
    column: $table.lastReloadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastEpgReloadAt => $composableBuilder(
    column: $table.lastEpgReloadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountJson => $composableBuilder(
    column: $table.accountJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get m3uHeaderJson => $composableBuilder(
    column: $table.m3uHeaderJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get liveCount => $composableBuilder(
    column: $table.liveCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get movieCount => $composableBuilder(
    column: $table.movieCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seriesCount => $composableBuilder(
    column: $table.seriesCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get programmeCount => $composableBuilder(
    column: $table.programmeCount,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> categoriesRefs(
    Expression<bool> Function($$CategoriesTableFilterComposer f) f,
  ) {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> channelsRefs(
    Expression<bool> Function($$ChannelsTableFilterComposer f) f,
  ) {
    final $$ChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableFilterComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> moviesRefs(
    Expression<bool> Function($$MoviesTableFilterComposer f) f,
  ) {
    final $$MoviesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.movies,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoviesTableFilterComposer(
            $db: $db,
            $table: $db.movies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> seriesRefs(
    Expression<bool> Function($$SeriesTableFilterComposer f) f,
  ) {
    final $$SeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableFilterComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> seasonsRefs(
    Expression<bool> Function($$SeasonsTableFilterComposer f) f,
  ) {
    final $$SeasonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seasons,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeasonsTableFilterComposer(
            $db: $db,
            $table: $db.seasons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> episodesRefs(
    Expression<bool> Function($$EpisodesTableFilterComposer f) f,
  ) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> epgChannelsRefs(
    Expression<bool> Function($$EpgChannelsTableFilterComposer f) f,
  ) {
    final $$EpgChannelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgChannels,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgChannelsTableFilterComposer(
            $db: $db,
            $table: $db.epgChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> programmesRefs(
    Expression<bool> Function($$ProgrammesTableFilterComposer f) f,
  ) {
    final $$ProgrammesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.programmes,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgrammesTableFilterComposer(
            $db: $db,
            $table: $db.programmes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> favoritesRefs(
    Expression<bool> Function($$FavoritesTableFilterComposer f) f,
  ) {
    final $$FavoritesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableFilterComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> favoriteTagsRefs(
    Expression<bool> Function($$FavoriteTagsTableFilterComposer f) f,
  ) {
    final $$FavoriteTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteTags,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTagsTableFilterComposer(
            $db: $db,
            $table: $db.favoriteTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> watchStatesRefs(
    Expression<bool> Function($$WatchStatesTableFilterComposer f) f,
  ) {
    final $$WatchStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchStates,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchStatesTableFilterComposer(
            $db: $db,
            $table: $db.watchStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lastWatchedLiveRefs(
    Expression<bool> Function($$LastWatchedLiveTableFilterComposer f) f,
  ) {
    final $$LastWatchedLiveTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lastWatchedLive,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LastWatchedLiveTableFilterComposer(
            $db: $db,
            $table: $db.lastWatchedLive,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get server => $composableBuilder(
    column: $table.server,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get m3uUrl => $composableBuilder(
    column: $table.m3uUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgUrl => $composableBuilder(
    column: $table.epgUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get epgShiftHours => $composableBuilder(
    column: $table.epgShiftHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reloadFrequencyHours => $composableBuilder(
    column: $table.reloadFrequencyHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userAgent => $composableBuilder(
    column: $table.userAgent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarId => $composableBuilder(
    column: $table.avatarId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasAccessPin => $composableBuilder(
    column: $table.hasAccessPin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReloadAt => $composableBuilder(
    column: $table.lastReloadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastEpgReloadAt => $composableBuilder(
    column: $table.lastEpgReloadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountJson => $composableBuilder(
    column: $table.accountJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get m3uHeaderJson => $composableBuilder(
    column: $table.m3uHeaderJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get liveCount => $composableBuilder(
    column: $table.liveCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get movieCount => $composableBuilder(
    column: $table.movieCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seriesCount => $composableBuilder(
    column: $table.seriesCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get programmeCount => $composableBuilder(
    column: $table.programmeCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PlaylistType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get server =>
      $composableBuilder(column: $table.server, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get m3uUrl =>
      $composableBuilder(column: $table.m3uUrl, builder: (column) => column);

  GeneratedColumn<String> get epgUrl =>
      $composableBuilder(column: $table.epgUrl, builder: (column) => column);

  GeneratedColumn<int> get epgShiftHours => $composableBuilder(
    column: $table.epgShiftHours,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reloadFrequencyHours => $composableBuilder(
    column: $table.reloadFrequencyHours,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userAgent =>
      $composableBuilder(column: $table.userAgent, builder: (column) => column);

  GeneratedColumn<String> get avatarId =>
      $composableBuilder(column: $table.avatarId, builder: (column) => column);

  GeneratedColumn<bool> get hasAccessPin => $composableBuilder(
    column: $table.hasAccessPin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReloadAt => $composableBuilder(
    column: $table.lastReloadAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastEpgReloadAt => $composableBuilder(
    column: $table.lastEpgReloadAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountJson => $composableBuilder(
    column: $table.accountJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get m3uHeaderJson => $composableBuilder(
    column: $table.m3uHeaderJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get liveCount =>
      $composableBuilder(column: $table.liveCount, builder: (column) => column);

  GeneratedColumn<int> get movieCount => $composableBuilder(
    column: $table.movieCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seriesCount => $composableBuilder(
    column: $table.seriesCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get programmeCount => $composableBuilder(
    column: $table.programmeCount,
    builder: (column) => column,
  );

  Expression<T> categoriesRefs<T extends Object>(
    Expression<T> Function($$CategoriesTableAnnotationComposer a) f,
  ) {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> channelsRefs<T extends Object>(
    Expression<T> Function($$ChannelsTableAnnotationComposer a) f,
  ) {
    final $$ChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.channels,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.channels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> moviesRefs<T extends Object>(
    Expression<T> Function($$MoviesTableAnnotationComposer a) f,
  ) {
    final $$MoviesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.movies,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MoviesTableAnnotationComposer(
            $db: $db,
            $table: $db.movies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> seriesRefs<T extends Object>(
    Expression<T> Function($$SeriesTableAnnotationComposer a) f,
  ) {
    final $$SeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> seasonsRefs<T extends Object>(
    Expression<T> Function($$SeasonsTableAnnotationComposer a) f,
  ) {
    final $$SeasonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seasons,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeasonsTableAnnotationComposer(
            $db: $db,
            $table: $db.seasons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> epgChannelsRefs<T extends Object>(
    Expression<T> Function($$EpgChannelsTableAnnotationComposer a) f,
  ) {
    final $$EpgChannelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.epgChannels,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpgChannelsTableAnnotationComposer(
            $db: $db,
            $table: $db.epgChannels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> programmesRefs<T extends Object>(
    Expression<T> Function($$ProgrammesTableAnnotationComposer a) f,
  ) {
    final $$ProgrammesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.programmes,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgrammesTableAnnotationComposer(
            $db: $db,
            $table: $db.programmes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> favoritesRefs<T extends Object>(
    Expression<T> Function($$FavoritesTableAnnotationComposer a) f,
  ) {
    final $$FavoritesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableAnnotationComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> favoriteTagsRefs<T extends Object>(
    Expression<T> Function($$FavoriteTagsTableAnnotationComposer a) f,
  ) {
    final $$FavoriteTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteTags,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> watchStatesRefs<T extends Object>(
    Expression<T> Function($$WatchStatesTableAnnotationComposer a) f,
  ) {
    final $$WatchStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchStates,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.watchStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> lastWatchedLiveRefs<T extends Object>(
    Expression<T> Function($$LastWatchedLiveTableAnnotationComposer a) f,
  ) {
    final $$LastWatchedLiveTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lastWatchedLive,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LastWatchedLiveTableAnnotationComposer(
            $db: $db,
            $table: $db.lastWatchedLive,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          PlaylistRow,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (PlaylistRow, $$PlaylistsTableReferences),
          PlaylistRow,
          PrefetchHooks Function({
            bool categoriesRefs,
            bool channelsRefs,
            bool moviesRefs,
            bool seriesRefs,
            bool seasonsRefs,
            bool episodesRefs,
            bool epgChannelsRefs,
            bool programmesRefs,
            bool favoritesRefs,
            bool favoriteTagsRefs,
            bool watchStatesRefs,
            bool lastWatchedLiveRefs,
            bool remindersRefs,
          })
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<PlaylistType> type = const Value.absent(),
                Value<String?> server = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> m3uUrl = const Value.absent(),
                Value<String?> epgUrl = const Value.absent(),
                Value<int> epgShiftHours = const Value.absent(),
                Value<int> reloadFrequencyHours = const Value.absent(),
                Value<String?> userAgent = const Value.absent(),
                Value<String?> avatarId = const Value.absent(),
                Value<bool> hasAccessPin = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastReloadAt = const Value.absent(),
                Value<DateTime?> lastEpgReloadAt = const Value.absent(),
                Value<String?> accountJson = const Value.absent(),
                Value<String?> m3uHeaderJson = const Value.absent(),
                Value<int> liveCount = const Value.absent(),
                Value<int> movieCount = const Value.absent(),
                Value<int> seriesCount = const Value.absent(),
                Value<int> programmeCount = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                type: type,
                server: server,
                username: username,
                m3uUrl: m3uUrl,
                epgUrl: epgUrl,
                epgShiftHours: epgShiftHours,
                reloadFrequencyHours: reloadFrequencyHours,
                userAgent: userAgent,
                avatarId: avatarId,
                hasAccessPin: hasAccessPin,
                sortIndex: sortIndex,
                createdAt: createdAt,
                lastReloadAt: lastReloadAt,
                lastEpgReloadAt: lastEpgReloadAt,
                accountJson: accountJson,
                m3uHeaderJson: m3uHeaderJson,
                liveCount: liveCount,
                movieCount: movieCount,
                seriesCount: seriesCount,
                programmeCount: programmeCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required PlaylistType type,
                Value<String?> server = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> m3uUrl = const Value.absent(),
                Value<String?> epgUrl = const Value.absent(),
                Value<int> epgShiftHours = const Value.absent(),
                Value<int> reloadFrequencyHours = const Value.absent(),
                Value<String?> userAgent = const Value.absent(),
                Value<String?> avatarId = const Value.absent(),
                Value<bool> hasAccessPin = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastReloadAt = const Value.absent(),
                Value<DateTime?> lastEpgReloadAt = const Value.absent(),
                Value<String?> accountJson = const Value.absent(),
                Value<String?> m3uHeaderJson = const Value.absent(),
                Value<int> liveCount = const Value.absent(),
                Value<int> movieCount = const Value.absent(),
                Value<int> seriesCount = const Value.absent(),
                Value<int> programmeCount = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                type: type,
                server: server,
                username: username,
                m3uUrl: m3uUrl,
                epgUrl: epgUrl,
                epgShiftHours: epgShiftHours,
                reloadFrequencyHours: reloadFrequencyHours,
                userAgent: userAgent,
                avatarId: avatarId,
                hasAccessPin: hasAccessPin,
                sortIndex: sortIndex,
                createdAt: createdAt,
                lastReloadAt: lastReloadAt,
                lastEpgReloadAt: lastEpgReloadAt,
                accountJson: accountJson,
                m3uHeaderJson: m3uHeaderJson,
                liveCount: liveCount,
                movieCount: movieCount,
                seriesCount: seriesCount,
                programmeCount: programmeCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, PlaylistRow>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoriesRefs = false,
                channelsRefs = false,
                moviesRefs = false,
                seriesRefs = false,
                seasonsRefs = false,
                episodesRefs = false,
                epgChannelsRefs = false,
                programmesRefs = false,
                favoritesRefs = false,
                favoriteTagsRefs = false,
                watchStatesRefs = false,
                lastWatchedLiveRefs = false,
                remindersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (categoriesRefs) db.categories,
                    if (channelsRefs) db.channels,
                    if (moviesRefs) db.movies,
                    if (seriesRefs) db.series,
                    if (seasonsRefs) db.seasons,
                    if (episodesRefs) db.episodes,
                    if (epgChannelsRefs) db.epgChannels,
                    if (programmesRefs) db.programmes,
                    if (favoritesRefs) db.favorites,
                    if (favoriteTagsRefs) db.favoriteTags,
                    if (watchStatesRefs) db.watchStates,
                    if (lastWatchedLiveRefs) db.lastWatchedLive,
                    if (remindersRefs) db.reminders,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (categoriesRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          CategoryRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._categoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).categoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (channelsRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          ChannelRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._channelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).channelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (moviesRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          MovieRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._moviesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).moviesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (seriesRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          SeriesRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._seriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (seasonsRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          SeasonRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._seasonsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).seasonsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (episodesRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          EpisodeRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._episodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).episodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (epgChannelsRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          EpgChannelRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._epgChannelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).epgChannelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (programmesRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          ProgrammeRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._programmesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).programmesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (favoritesRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          FavoriteRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._favoritesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).favoritesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (favoriteTagsRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          FavoriteTagRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._favoriteTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).favoriteTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (watchStatesRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          WatchStateRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._watchStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).watchStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (lastWatchedLiveRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          LastWatchedLiveRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._lastWatchedLiveRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).lastWatchedLiveRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          PlaylistRow,
                          $PlaylistsTable,
                          ReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      PlaylistRow,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (PlaylistRow, $$PlaylistsTableReferences),
      PlaylistRow,
      PrefetchHooks Function({
        bool categoriesRefs,
        bool channelsRefs,
        bool moviesRefs,
        bool seriesRefs,
        bool seasonsRefs,
        bool episodesRefs,
        bool epgChannelsRefs,
        bool programmesRefs,
        bool favoritesRefs,
        bool favoriteTagsRefs,
        bool watchStatesRefs,
        bool lastWatchedLiveRefs,
        bool remindersRefs,
      })
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  required int playlistId,
  required SectionKind kind,
  required String providerId,
  required String name,
  Value<String?> localName,
  Value<String?> parentId,
  Value<int> sortIndex,
  Value<int?> customIndex,
  Value<bool> hidden,
  Value<bool> locked,
  Value<bool> removed,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<int> playlistId,
  Value<SectionKind> kind,
  Value<String> providerId,
  Value<String> name,
  Value<String?> localName,
  Value<String?> parentId,
  Value<int> sortIndex,
  Value<int?> customIndex,
  Value<bool> hidden,
  Value<bool> locked,
  Value<bool> removed,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('categories__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SectionKind, SectionKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localName => $composableBuilder(
    column: $table.localName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customIndex => $composableBuilder(
    column: $table.customIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localName => $composableBuilder(
    column: $table.localName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customIndex => $composableBuilder(
    column: $table.customIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SectionKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get localName =>
      $composableBuilder(column: $table.localName, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<int> get customIndex => $composableBuilder(
    column: $table.customIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<bool> get removed =>
      $composableBuilder(column: $table.removed, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (CategoryRow, $$CategoriesTableReferences),
          CategoryRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<SectionKind> kind = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> localName = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int?> customIndex = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<bool> removed = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                playlistId: playlistId,
                kind: kind,
                providerId: providerId,
                name: name,
                localName: localName,
                parentId: parentId,
                sortIndex: sortIndex,
                customIndex: customIndex,
                hidden: hidden,
                locked: locked,
                removed: removed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required SectionKind kind,
                required String providerId,
                required String name,
                Value<String?> localName = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int?> customIndex = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<bool> removed = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                playlistId: playlistId,
                kind: kind,
                providerId: providerId,
                name: name,
                localName: localName,
                parentId: parentId,
                sortIndex: sortIndex,
                customIndex: customIndex,
                hidden: hidden,
                locked: locked,
                removed: removed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, CategoryRow>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$CategoriesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$CategoriesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (CategoryRow, $$CategoriesTableReferences),
      CategoryRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$ChannelsTableCreateCompanionBuilder = ChannelsCompanion Function({
  Value<int> id,
  required int playlistId,
  required String providerId,
  Value<int?> num,
  required String name,
  required String displayName,
  Value<String?> quality,
  Value<String?> logo,
  Value<String?> categoryId,
  Value<String?> epgId,
  Value<String?> matchedEpgId,
  Value<String?> customEpgId,
  Value<int> archiveDays,
  Value<String?> catchupType,
  Value<String?> catchupSource,
  Value<String?> streamUrl,
  Value<String?> directSource,
  Value<String?> headersJson,
  Value<bool> unsupported,
  Value<DateTime?> added,
  Value<int> sortIndex,
  Value<int?> customIndex,
  Value<bool> hidden,
  Value<bool> locked,
  Value<bool> removed,
});
typedef $$ChannelsTableUpdateCompanionBuilder = ChannelsCompanion Function({
  Value<int> id,
  Value<int> playlistId,
  Value<String> providerId,
  Value<int?> num,
  Value<String> name,
  Value<String> displayName,
  Value<String?> quality,
  Value<String?> logo,
  Value<String?> categoryId,
  Value<String?> epgId,
  Value<String?> matchedEpgId,
  Value<String?> customEpgId,
  Value<int> archiveDays,
  Value<String?> catchupType,
  Value<String?> catchupSource,
  Value<String?> streamUrl,
  Value<String?> directSource,
  Value<String?> headersJson,
  Value<bool> unsupported,
  Value<DateTime?> added,
  Value<int> sortIndex,
  Value<int?> customIndex,
  Value<bool> hidden,
  Value<bool> locked,
  Value<bool> removed,
});

final class $$ChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $ChannelsTable, ChannelRow> {
  $$ChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('channels__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get num => $composableBuilder(
    column: $table.num,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logo => $composableBuilder(
    column: $table.logo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgId => $composableBuilder(
    column: $table.epgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchedEpgId => $composableBuilder(
    column: $table.matchedEpgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customEpgId => $composableBuilder(
    column: $table.customEpgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archiveDays => $composableBuilder(
    column: $table.archiveDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catchupType => $composableBuilder(
    column: $table.catchupType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catchupSource => $composableBuilder(
    column: $table.catchupSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directSource => $composableBuilder(
    column: $table.directSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unsupported => $composableBuilder(
    column: $table.unsupported,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customIndex => $composableBuilder(
    column: $table.customIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get num => $composableBuilder(
    column: $table.num,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logo => $composableBuilder(
    column: $table.logo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgId => $composableBuilder(
    column: $table.epgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchedEpgId => $composableBuilder(
    column: $table.matchedEpgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customEpgId => $composableBuilder(
    column: $table.customEpgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archiveDays => $composableBuilder(
    column: $table.archiveDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catchupType => $composableBuilder(
    column: $table.catchupType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catchupSource => $composableBuilder(
    column: $table.catchupSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directSource => $composableBuilder(
    column: $table.directSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unsupported => $composableBuilder(
    column: $table.unsupported,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customIndex => $composableBuilder(
    column: $table.customIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get locked => $composableBuilder(
    column: $table.locked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get num =>
      $composableBuilder(column: $table.num, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get logo =>
      $composableBuilder(column: $table.logo, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get epgId =>
      $composableBuilder(column: $table.epgId, builder: (column) => column);

  GeneratedColumn<String> get matchedEpgId => $composableBuilder(
    column: $table.matchedEpgId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customEpgId => $composableBuilder(
    column: $table.customEpgId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archiveDays => $composableBuilder(
    column: $table.archiveDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get catchupType => $composableBuilder(
    column: $table.catchupType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get catchupSource => $composableBuilder(
    column: $table.catchupSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get directSource => $composableBuilder(
    column: $table.directSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get unsupported => $composableBuilder(
    column: $table.unsupported,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get added =>
      $composableBuilder(column: $table.added, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<int> get customIndex => $composableBuilder(
    column: $table.customIndex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get locked =>
      $composableBuilder(column: $table.locked, builder: (column) => column);

  GeneratedColumn<bool> get removed =>
      $composableBuilder(column: $table.removed, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChannelsTable,
          ChannelRow,
          $$ChannelsTableFilterComposer,
          $$ChannelsTableOrderingComposer,
          $$ChannelsTableAnnotationComposer,
          $$ChannelsTableCreateCompanionBuilder,
          $$ChannelsTableUpdateCompanionBuilder,
          (ChannelRow, $$ChannelsTableReferences),
          ChannelRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$ChannelsTableTableManager(_$AppDatabase db, $ChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<int?> num = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> quality = const Value.absent(),
                Value<String?> logo = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> epgId = const Value.absent(),
                Value<String?> matchedEpgId = const Value.absent(),
                Value<String?> customEpgId = const Value.absent(),
                Value<int> archiveDays = const Value.absent(),
                Value<String?> catchupType = const Value.absent(),
                Value<String?> catchupSource = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> directSource = const Value.absent(),
                Value<String?> headersJson = const Value.absent(),
                Value<bool> unsupported = const Value.absent(),
                Value<DateTime?> added = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int?> customIndex = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<bool> removed = const Value.absent(),
              }) => ChannelsCompanion(
                id: id,
                playlistId: playlistId,
                providerId: providerId,
                num: num,
                name: name,
                displayName: displayName,
                quality: quality,
                logo: logo,
                categoryId: categoryId,
                epgId: epgId,
                matchedEpgId: matchedEpgId,
                customEpgId: customEpgId,
                archiveDays: archiveDays,
                catchupType: catchupType,
                catchupSource: catchupSource,
                streamUrl: streamUrl,
                directSource: directSource,
                headersJson: headersJson,
                unsupported: unsupported,
                added: added,
                sortIndex: sortIndex,
                customIndex: customIndex,
                hidden: hidden,
                locked: locked,
                removed: removed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String providerId,
                Value<int?> num = const Value.absent(),
                required String name,
                required String displayName,
                Value<String?> quality = const Value.absent(),
                Value<String?> logo = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> epgId = const Value.absent(),
                Value<String?> matchedEpgId = const Value.absent(),
                Value<String?> customEpgId = const Value.absent(),
                Value<int> archiveDays = const Value.absent(),
                Value<String?> catchupType = const Value.absent(),
                Value<String?> catchupSource = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> directSource = const Value.absent(),
                Value<String?> headersJson = const Value.absent(),
                Value<bool> unsupported = const Value.absent(),
                Value<DateTime?> added = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int?> customIndex = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> locked = const Value.absent(),
                Value<bool> removed = const Value.absent(),
              }) => ChannelsCompanion.insert(
                id: id,
                playlistId: playlistId,
                providerId: providerId,
                num: num,
                name: name,
                displayName: displayName,
                quality: quality,
                logo: logo,
                categoryId: categoryId,
                epgId: epgId,
                matchedEpgId: matchedEpgId,
                customEpgId: customEpgId,
                archiveDays: archiveDays,
                catchupType: catchupType,
                catchupSource: catchupSource,
                streamUrl: streamUrl,
                directSource: directSource,
                headersJson: headersJson,
                unsupported: unsupported,
                added: added,
                sortIndex: sortIndex,
                customIndex: customIndex,
                hidden: hidden,
                locked: locked,
                removed: removed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChannelsTable, ChannelRow>(table),
                  $$ChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$ChannelsTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$ChannelsTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChannelsTable,
      ChannelRow,
      $$ChannelsTableFilterComposer,
      $$ChannelsTableOrderingComposer,
      $$ChannelsTableAnnotationComposer,
      $$ChannelsTableCreateCompanionBuilder,
      $$ChannelsTableUpdateCompanionBuilder,
      (ChannelRow, $$ChannelsTableReferences),
      ChannelRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$MoviesTableCreateCompanionBuilder = MoviesCompanion Function({
  Value<int> id,
  required int playlistId,
  required String providerId,
  required String name,
  Value<String?> categoryId,
  Value<String?> poster,
  Value<double?> rating,
  Value<DateTime?> added,
  Value<String?> containerExt,
  Value<int?> tmdbId,
  Value<int?> year,
  Value<String?> streamUrl,
  Value<String?> directSource,
  Value<String?> headersJson,
  Value<int> sortIndex,
  Value<bool> hidden,
  Value<bool> removed,
  Value<String?> infoJson,
  Value<DateTime?> infoFetchedAt,
});
typedef $$MoviesTableUpdateCompanionBuilder = MoviesCompanion Function({
  Value<int> id,
  Value<int> playlistId,
  Value<String> providerId,
  Value<String> name,
  Value<String?> categoryId,
  Value<String?> poster,
  Value<double?> rating,
  Value<DateTime?> added,
  Value<String?> containerExt,
  Value<int?> tmdbId,
  Value<int?> year,
  Value<String?> streamUrl,
  Value<String?> directSource,
  Value<String?> headersJson,
  Value<int> sortIndex,
  Value<bool> hidden,
  Value<bool> removed,
  Value<String?> infoJson,
  Value<DateTime?> infoFetchedAt,
});

final class $$MoviesTableReferences
    extends BaseReferences<_$AppDatabase, $MoviesTable, MovieRow> {
  $$MoviesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('movies__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MoviesTableFilterComposer
    extends Composer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poster => $composableBuilder(
    column: $table.poster,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directSource => $composableBuilder(
    column: $table.directSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get infoJson => $composableBuilder(
    column: $table.infoJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get infoFetchedAt => $composableBuilder(
    column: $table.infoFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MoviesTableOrderingComposer
    extends Composer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poster => $composableBuilder(
    column: $table.poster,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directSource => $composableBuilder(
    column: $table.directSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get infoJson => $composableBuilder(
    column: $table.infoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get infoFetchedAt => $composableBuilder(
    column: $table.infoFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MoviesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get poster =>
      $composableBuilder(column: $table.poster, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get added =>
      $composableBuilder(column: $table.added, builder: (column) => column);

  GeneratedColumn<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get directSource => $composableBuilder(
    column: $table.directSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get removed =>
      $composableBuilder(column: $table.removed, builder: (column) => column);

  GeneratedColumn<String> get infoJson =>
      $composableBuilder(column: $table.infoJson, builder: (column) => column);

  GeneratedColumn<DateTime> get infoFetchedAt => $composableBuilder(
    column: $table.infoFetchedAt,
    builder: (column) => column,
  );

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MoviesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MoviesTable,
          MovieRow,
          $$MoviesTableFilterComposer,
          $$MoviesTableOrderingComposer,
          $$MoviesTableAnnotationComposer,
          $$MoviesTableCreateCompanionBuilder,
          $$MoviesTableUpdateCompanionBuilder,
          (MovieRow, $$MoviesTableReferences),
          MovieRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$MoviesTableTableManager(_$AppDatabase db, $MoviesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoviesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoviesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoviesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> poster = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<DateTime?> added = const Value.absent(),
                Value<String?> containerExt = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> directSource = const Value.absent(),
                Value<String?> headersJson = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> removed = const Value.absent(),
                Value<String?> infoJson = const Value.absent(),
                Value<DateTime?> infoFetchedAt = const Value.absent(),
              }) => MoviesCompanion(
                id: id,
                playlistId: playlistId,
                providerId: providerId,
                name: name,
                categoryId: categoryId,
                poster: poster,
                rating: rating,
                added: added,
                containerExt: containerExt,
                tmdbId: tmdbId,
                year: year,
                streamUrl: streamUrl,
                directSource: directSource,
                headersJson: headersJson,
                sortIndex: sortIndex,
                hidden: hidden,
                removed: removed,
                infoJson: infoJson,
                infoFetchedAt: infoFetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String providerId,
                required String name,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> poster = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<DateTime?> added = const Value.absent(),
                Value<String?> containerExt = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> directSource = const Value.absent(),
                Value<String?> headersJson = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> removed = const Value.absent(),
                Value<String?> infoJson = const Value.absent(),
                Value<DateTime?> infoFetchedAt = const Value.absent(),
              }) => MoviesCompanion.insert(
                id: id,
                playlistId: playlistId,
                providerId: providerId,
                name: name,
                categoryId: categoryId,
                poster: poster,
                rating: rating,
                added: added,
                containerExt: containerExt,
                tmdbId: tmdbId,
                year: year,
                streamUrl: streamUrl,
                directSource: directSource,
                headersJson: headersJson,
                sortIndex: sortIndex,
                hidden: hidden,
                removed: removed,
                infoJson: infoJson,
                infoFetchedAt: infoFetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MoviesTable, MovieRow>(table),
                  $$MoviesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$MoviesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$MoviesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MoviesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MoviesTable,
      MovieRow,
      $$MoviesTableFilterComposer,
      $$MoviesTableOrderingComposer,
      $$MoviesTableAnnotationComposer,
      $$MoviesTableCreateCompanionBuilder,
      $$MoviesTableUpdateCompanionBuilder,
      (MovieRow, $$MoviesTableReferences),
      MovieRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$SeriesTableCreateCompanionBuilder = SeriesCompanion Function({
  Value<int> id,
  required int playlistId,
  required String providerId,
  required String name,
  Value<String?> categoryId,
  Value<String?> cover,
  Value<String?> plot,
  Value<String?> cast,
  Value<String?> director,
  Value<String?> genre,
  Value<String?> releaseDate,
  Value<DateTime?> lastModified,
  Value<double?> rating,
  Value<String?> backdropsJson,
  Value<String?> youtubeTrailer,
  Value<int?> tmdbId,
  Value<int?> year,
  Value<int> sortIndex,
  Value<bool> hidden,
  Value<bool> removed,
  Value<String?> infoJson,
  Value<DateTime?> infoFetchedAt,
});
typedef $$SeriesTableUpdateCompanionBuilder = SeriesCompanion Function({
  Value<int> id,
  Value<int> playlistId,
  Value<String> providerId,
  Value<String> name,
  Value<String?> categoryId,
  Value<String?> cover,
  Value<String?> plot,
  Value<String?> cast,
  Value<String?> director,
  Value<String?> genre,
  Value<String?> releaseDate,
  Value<DateTime?> lastModified,
  Value<double?> rating,
  Value<String?> backdropsJson,
  Value<String?> youtubeTrailer,
  Value<int?> tmdbId,
  Value<int?> year,
  Value<int> sortIndex,
  Value<bool> hidden,
  Value<bool> removed,
  Value<String?> infoJson,
  Value<DateTime?> infoFetchedAt,
});

final class $$SeriesTableReferences
    extends BaseReferences<_$AppDatabase, $SeriesTable, SeriesRow> {
  $$SeriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('series__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SeriesTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cast => $composableBuilder(
    column: $table.cast,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropsJson => $composableBuilder(
    column: $table.backdropsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get youtubeTrailer => $composableBuilder(
    column: $table.youtubeTrailer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get infoJson => $composableBuilder(
    column: $table.infoJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get infoFetchedAt => $composableBuilder(
    column: $table.infoFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cast => $composableBuilder(
    column: $table.cast,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get director => $composableBuilder(
    column: $table.director,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropsJson => $composableBuilder(
    column: $table.backdropsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get youtubeTrailer => $composableBuilder(
    column: $table.youtubeTrailer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get infoJson => $composableBuilder(
    column: $table.infoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get infoFetchedAt => $composableBuilder(
    column: $table.infoFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesTable> {
  $$SeriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<String> get cast =>
      $composableBuilder(column: $table.cast, builder: (column) => column);

  GeneratedColumn<String> get director =>
      $composableBuilder(column: $table.director, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get backdropsJson => $composableBuilder(
    column: $table.backdropsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get youtubeTrailer => $composableBuilder(
    column: $table.youtubeTrailer,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get removed =>
      $composableBuilder(column: $table.removed, builder: (column) => column);

  GeneratedColumn<String> get infoJson =>
      $composableBuilder(column: $table.infoJson, builder: (column) => column);

  GeneratedColumn<DateTime> get infoFetchedAt => $composableBuilder(
    column: $table.infoFetchedAt,
    builder: (column) => column,
  );

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesTable,
          SeriesRow,
          $$SeriesTableFilterComposer,
          $$SeriesTableOrderingComposer,
          $$SeriesTableAnnotationComposer,
          $$SeriesTableCreateCompanionBuilder,
          $$SeriesTableUpdateCompanionBuilder,
          (SeriesRow, $$SeriesTableReferences),
          SeriesRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$SeriesTableTableManager(_$AppDatabase db, $SeriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> cast = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<DateTime?> lastModified = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> backdropsJson = const Value.absent(),
                Value<String?> youtubeTrailer = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> removed = const Value.absent(),
                Value<String?> infoJson = const Value.absent(),
                Value<DateTime?> infoFetchedAt = const Value.absent(),
              }) => SeriesCompanion(
                id: id,
                playlistId: playlistId,
                providerId: providerId,
                name: name,
                categoryId: categoryId,
                cover: cover,
                plot: plot,
                cast: cast,
                director: director,
                genre: genre,
                releaseDate: releaseDate,
                lastModified: lastModified,
                rating: rating,
                backdropsJson: backdropsJson,
                youtubeTrailer: youtubeTrailer,
                tmdbId: tmdbId,
                year: year,
                sortIndex: sortIndex,
                hidden: hidden,
                removed: removed,
                infoJson: infoJson,
                infoFetchedAt: infoFetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String providerId,
                required String name,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<String?> cast = const Value.absent(),
                Value<String?> director = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<DateTime?> lastModified = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> backdropsJson = const Value.absent(),
                Value<String?> youtubeTrailer = const Value.absent(),
                Value<int?> tmdbId = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> removed = const Value.absent(),
                Value<String?> infoJson = const Value.absent(),
                Value<DateTime?> infoFetchedAt = const Value.absent(),
              }) => SeriesCompanion.insert(
                id: id,
                playlistId: playlistId,
                providerId: providerId,
                name: name,
                categoryId: categoryId,
                cover: cover,
                plot: plot,
                cast: cast,
                director: director,
                genre: genre,
                releaseDate: releaseDate,
                lastModified: lastModified,
                rating: rating,
                backdropsJson: backdropsJson,
                youtubeTrailer: youtubeTrailer,
                tmdbId: tmdbId,
                year: year,
                sortIndex: sortIndex,
                hidden: hidden,
                removed: removed,
                infoJson: infoJson,
                infoFetchedAt: infoFetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeriesTable, SeriesRow>(table),
                  $$SeriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$SeriesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$SeriesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesTable,
      SeriesRow,
      $$SeriesTableFilterComposer,
      $$SeriesTableOrderingComposer,
      $$SeriesTableAnnotationComposer,
      $$SeriesTableCreateCompanionBuilder,
      $$SeriesTableUpdateCompanionBuilder,
      (SeriesRow, $$SeriesTableReferences),
      SeriesRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$SeasonsTableCreateCompanionBuilder = SeasonsCompanion Function({
  Value<int> id,
  required int playlistId,
  required String seriesId,
  required int seasonNumber,
  Value<String?> name,
  Value<String?> cover,
  Value<String?> airDate,
  Value<int?> episodeCount,
  Value<String?> overview,
});
typedef $$SeasonsTableUpdateCompanionBuilder = SeasonsCompanion Function({
  Value<int> id,
  Value<int> playlistId,
  Value<String> seriesId,
  Value<int> seasonNumber,
  Value<String?> name,
  Value<String?> cover,
  Value<String?> airDate,
  Value<int?> episodeCount,
  Value<String?> overview,
});

final class $$SeasonsTableReferences
    extends BaseReferences<_$AppDatabase, $SeasonsTable, SeasonRow> {
  $$SeasonsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('seasons__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SeasonsTableFilterComposer
    extends Composer<_$AppDatabase, $SeasonsTable> {
  $$SeasonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeasonsTableOrderingComposer
    extends Composer<_$AppDatabase, $SeasonsTable> {
  $$SeasonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeasonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeasonsTable> {
  $$SeasonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<String> get airDate =>
      $composableBuilder(column: $table.airDate, builder: (column) => column);

  GeneratedColumn<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get overview =>
      $composableBuilder(column: $table.overview, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeasonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeasonsTable,
          SeasonRow,
          $$SeasonsTableFilterComposer,
          $$SeasonsTableOrderingComposer,
          $$SeasonsTableAnnotationComposer,
          $$SeasonsTableCreateCompanionBuilder,
          $$SeasonsTableUpdateCompanionBuilder,
          (SeasonRow, $$SeasonsTableReferences),
          SeasonRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$SeasonsTableTableManager(_$AppDatabase db, $SeasonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeasonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeasonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeasonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<int> seasonNumber = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<int?> episodeCount = const Value.absent(),
                Value<String?> overview = const Value.absent(),
              }) => SeasonsCompanion(
                id: id,
                playlistId: playlistId,
                seriesId: seriesId,
                seasonNumber: seasonNumber,
                name: name,
                cover: cover,
                airDate: airDate,
                episodeCount: episodeCount,
                overview: overview,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String seriesId,
                required int seasonNumber,
                Value<String?> name = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<String?> airDate = const Value.absent(),
                Value<int?> episodeCount = const Value.absent(),
                Value<String?> overview = const Value.absent(),
              }) => SeasonsCompanion.insert(
                id: id,
                playlistId: playlistId,
                seriesId: seriesId,
                seasonNumber: seasonNumber,
                name: name,
                cover: cover,
                airDate: airDate,
                episodeCount: episodeCount,
                overview: overview,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeasonsTable, SeasonRow>(table),
                  $$SeasonsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$SeasonsTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$SeasonsTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SeasonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeasonsTable,
      SeasonRow,
      $$SeasonsTableFilterComposer,
      $$SeasonsTableOrderingComposer,
      $$SeasonsTableAnnotationComposer,
      $$SeasonsTableCreateCompanionBuilder,
      $$SeasonsTableUpdateCompanionBuilder,
      (SeasonRow, $$SeasonsTableReferences),
      SeasonRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$EpisodesTableCreateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  required int playlistId,
  required String providerId,
  required String seriesId,
  required int season,
  required int episodeNum,
  required String title,
  Value<String?> containerExt,
  Value<String?> plot,
  Value<int?> durationSecs,
  Value<String?> releaseDate,
  Value<String?> image,
  Value<double?> rating,
  Value<String?> streamUrl,
  Value<String?> directSource,
  Value<DateTime?> added,
});
typedef $$EpisodesTableUpdateCompanionBuilder = EpisodesCompanion Function({
  Value<int> id,
  Value<int> playlistId,
  Value<String> providerId,
  Value<String> seriesId,
  Value<int> season,
  Value<int> episodeNum,
  Value<String> title,
  Value<String?> containerExt,
  Value<String?> plot,
  Value<int?> durationSecs,
  Value<String?> releaseDate,
  Value<String?> image,
  Value<double?> rating,
  Value<String?> streamUrl,
  Value<String?> directSource,
  Value<DateTime?> added,
});

final class $$EpisodesTableReferences
    extends BaseReferences<_$AppDatabase, $EpisodesTable, EpisodeRow> {
  $$EpisodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('episodes__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNum => $composableBuilder(
    column: $table.episodeNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSecs => $composableBuilder(
    column: $table.durationSecs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directSource => $composableBuilder(
    column: $table.directSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNum => $composableBuilder(
    column: $table.episodeNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plot => $composableBuilder(
    column: $table.plot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSecs => $composableBuilder(
    column: $table.durationSecs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directSource => $composableBuilder(
    column: $table.directSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episodeNum => $composableBuilder(
    column: $table.episodeNum,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get containerExt => $composableBuilder(
    column: $table.containerExt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plot =>
      $composableBuilder(column: $table.plot, builder: (column) => column);

  GeneratedColumn<int> get durationSecs => $composableBuilder(
    column: $table.durationSecs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get image =>
      $composableBuilder(column: $table.image, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get directSource => $composableBuilder(
    column: $table.directSource,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get added =>
      $composableBuilder(column: $table.added, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodesTable,
          EpisodeRow,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (EpisodeRow, $$EpisodesTableReferences),
          EpisodeRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$EpisodesTableTableManager(_$AppDatabase db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> seriesId = const Value.absent(),
                Value<int> season = const Value.absent(),
                Value<int> episodeNum = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> containerExt = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<int?> durationSecs = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> directSource = const Value.absent(),
                Value<DateTime?> added = const Value.absent(),
              }) => EpisodesCompanion(
                id: id,
                playlistId: playlistId,
                providerId: providerId,
                seriesId: seriesId,
                season: season,
                episodeNum: episodeNum,
                title: title,
                containerExt: containerExt,
                plot: plot,
                durationSecs: durationSecs,
                releaseDate: releaseDate,
                image: image,
                rating: rating,
                streamUrl: streamUrl,
                directSource: directSource,
                added: added,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String providerId,
                required String seriesId,
                required int season,
                required int episodeNum,
                required String title,
                Value<String?> containerExt = const Value.absent(),
                Value<String?> plot = const Value.absent(),
                Value<int?> durationSecs = const Value.absent(),
                Value<String?> releaseDate = const Value.absent(),
                Value<String?> image = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<String?> streamUrl = const Value.absent(),
                Value<String?> directSource = const Value.absent(),
                Value<DateTime?> added = const Value.absent(),
              }) => EpisodesCompanion.insert(
                id: id,
                playlistId: playlistId,
                providerId: providerId,
                seriesId: seriesId,
                season: season,
                episodeNum: episodeNum,
                title: title,
                containerExt: containerExt,
                plot: plot,
                durationSecs: durationSecs,
                releaseDate: releaseDate,
                image: image,
                rating: rating,
                streamUrl: streamUrl,
                directSource: directSource,
                added: added,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpisodesTable, EpisodeRow>(table),
                  $$EpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$EpisodesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$EpisodesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodesTable,
      EpisodeRow,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (EpisodeRow, $$EpisodesTableReferences),
      EpisodeRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$EpgChannelsTableCreateCompanionBuilder =
    EpgChannelsCompanion Function({
      Value<int> id,
      required int playlistId,
      required String epgId,
      required String displayName,
      required String normalized,
      Value<String?> icon,
    });
typedef $$EpgChannelsTableUpdateCompanionBuilder =
    EpgChannelsCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<String> epgId,
      Value<String> displayName,
      Value<String> normalized,
      Value<String?> icon,
    });

final class $$EpgChannelsTableReferences
    extends BaseReferences<_$AppDatabase, $EpgChannelsTable, EpgChannelRow> {
  $$EpgChannelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('epg_channels__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpgChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgId => $composableBuilder(
    column: $table.epgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgId => $composableBuilder(
    column: $table.epgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpgChannelsTable> {
  $$EpgChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get epgId =>
      $composableBuilder(column: $table.epgId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get normalized => $composableBuilder(
    column: $table.normalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpgChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpgChannelsTable,
          EpgChannelRow,
          $$EpgChannelsTableFilterComposer,
          $$EpgChannelsTableOrderingComposer,
          $$EpgChannelsTableAnnotationComposer,
          $$EpgChannelsTableCreateCompanionBuilder,
          $$EpgChannelsTableUpdateCompanionBuilder,
          (EpgChannelRow, $$EpgChannelsTableReferences),
          EpgChannelRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$EpgChannelsTableTableManager(_$AppDatabase db, $EpgChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpgChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpgChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpgChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> epgId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> normalized = const Value.absent(),
                Value<String?> icon = const Value.absent(),
              }) => EpgChannelsCompanion(
                id: id,
                playlistId: playlistId,
                epgId: epgId,
                displayName: displayName,
                normalized: normalized,
                icon: icon,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String epgId,
                required String displayName,
                required String normalized,
                Value<String?> icon = const Value.absent(),
              }) => EpgChannelsCompanion.insert(
                id: id,
                playlistId: playlistId,
                epgId: epgId,
                displayName: displayName,
                normalized: normalized,
                icon: icon,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EpgChannelsTable, EpgChannelRow>(table),
                  $$EpgChannelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$EpgChannelsTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$EpgChannelsTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpgChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpgChannelsTable,
      EpgChannelRow,
      $$EpgChannelsTableFilterComposer,
      $$EpgChannelsTableOrderingComposer,
      $$EpgChannelsTableAnnotationComposer,
      $$EpgChannelsTableCreateCompanionBuilder,
      $$EpgChannelsTableUpdateCompanionBuilder,
      (EpgChannelRow, $$EpgChannelsTableReferences),
      EpgChannelRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$ProgrammesTableCreateCompanionBuilder = ProgrammesCompanion Function({
  Value<int> id,
  required int playlistId,
  required String epgChannelId,
  required int start,
  required int stop,
  required String title,
  Value<String?> subTitle,
  Value<String?> description,
  Value<String?> category,
  Value<String?> episodeNum,
  Value<String?> icon,
  Value<String?> rating,
});
typedef $$ProgrammesTableUpdateCompanionBuilder = ProgrammesCompanion Function({
  Value<int> id,
  Value<int> playlistId,
  Value<String> epgChannelId,
  Value<int> start,
  Value<int> stop,
  Value<String> title,
  Value<String?> subTitle,
  Value<String?> description,
  Value<String?> category,
  Value<String?> episodeNum,
  Value<String?> icon,
  Value<String?> rating,
});

final class $$ProgrammesTableReferences
    extends BaseReferences<_$AppDatabase, $ProgrammesTable, ProgrammeRow> {
  $$ProgrammesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('programmes__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProgrammesTableFilterComposer
    extends Composer<_$AppDatabase, $ProgrammesTable> {
  $$ProgrammesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stop => $composableBuilder(
    column: $table.stop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subTitle => $composableBuilder(
    column: $table.subTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeNum => $composableBuilder(
    column: $table.episodeNum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProgrammesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgrammesTable> {
  $$ProgrammesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stop => $composableBuilder(
    column: $table.stop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subTitle => $composableBuilder(
    column: $table.subTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeNum => $composableBuilder(
    column: $table.episodeNum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProgrammesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgrammesTable> {
  $$ProgrammesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<int> get stop =>
      $composableBuilder(column: $table.stop, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subTitle =>
      $composableBuilder(column: $table.subTitle, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get episodeNum => $composableBuilder(
    column: $table.episodeNum,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProgrammesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgrammesTable,
          ProgrammeRow,
          $$ProgrammesTableFilterComposer,
          $$ProgrammesTableOrderingComposer,
          $$ProgrammesTableAnnotationComposer,
          $$ProgrammesTableCreateCompanionBuilder,
          $$ProgrammesTableUpdateCompanionBuilder,
          (ProgrammeRow, $$ProgrammesTableReferences),
          ProgrammeRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$ProgrammesTableTableManager(_$AppDatabase db, $ProgrammesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgrammesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgrammesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgrammesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> epgChannelId = const Value.absent(),
                Value<int> start = const Value.absent(),
                Value<int> stop = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> subTitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> episodeNum = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> rating = const Value.absent(),
              }) => ProgrammesCompanion(
                id: id,
                playlistId: playlistId,
                epgChannelId: epgChannelId,
                start: start,
                stop: stop,
                title: title,
                subTitle: subTitle,
                description: description,
                category: category,
                episodeNum: episodeNum,
                icon: icon,
                rating: rating,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String epgChannelId,
                required int start,
                required int stop,
                required String title,
                Value<String?> subTitle = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> episodeNum = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> rating = const Value.absent(),
              }) => ProgrammesCompanion.insert(
                id: id,
                playlistId: playlistId,
                epgChannelId: epgChannelId,
                start: start,
                stop: stop,
                title: title,
                subTitle: subTitle,
                description: description,
                category: category,
                episodeNum: episodeNum,
                icon: icon,
                rating: rating,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProgrammesTable, ProgrammeRow>(table),
                  $$ProgrammesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$ProgrammesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$ProgrammesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProgrammesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgrammesTable,
      ProgrammeRow,
      $$ProgrammesTableFilterComposer,
      $$ProgrammesTableOrderingComposer,
      $$ProgrammesTableAnnotationComposer,
      $$ProgrammesTableCreateCompanionBuilder,
      $$ProgrammesTableUpdateCompanionBuilder,
      (ProgrammeRow, $$ProgrammesTableReferences),
      ProgrammeRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$FavoritesTableCreateCompanionBuilder = FavoritesCompanion Function({
  Value<int> id,
  required int playlistId,
  required ItemType itemType,
  required String providerId,
  required DateTime addedAt,
  Value<int?> customIndex,
});
typedef $$FavoritesTableUpdateCompanionBuilder = FavoritesCompanion Function({
  Value<int> id,
  Value<int> playlistId,
  Value<ItemType> itemType,
  Value<String> providerId,
  Value<DateTime> addedAt,
  Value<int?> customIndex,
});

final class $$FavoritesTableReferences
    extends BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow> {
  $$FavoritesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('favorites__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FavoriteTagLinksTable, List<FavoriteTagLinkRow>>
  _favoriteTagLinksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favoriteTagLinks,
    aliasName: 'favorites__id__favorite_tag_links__favorite_id',
  );

  $$FavoriteTagLinksTableProcessedTableManager get favoriteTagLinksRefs {
    final manager = $$FavoriteTagLinksTableTableManager(
      $_db,
      $_db.favoriteTagLinks,
    ).filter((f) => f.favoriteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _favoriteTagLinksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ItemType, ItemType, int> get itemType =>
      $composableBuilder(
        column: $table.itemType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customIndex => $composableBuilder(
    column: $table.customIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> favoriteTagLinksRefs(
    Expression<bool> Function($$FavoriteTagLinksTableFilterComposer f) f,
  ) {
    final $$FavoriteTagLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteTagLinks,
      getReferencedColumn: (t) => t.favoriteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTagLinksTableFilterComposer(
            $db: $db,
            $table: $db.favoriteTagLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customIndex => $composableBuilder(
    column: $table.customIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemType, int> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get customIndex => $composableBuilder(
    column: $table.customIndex,
    builder: (column) => column,
  );

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> favoriteTagLinksRefs<T extends Object>(
    Expression<T> Function($$FavoriteTagLinksTableAnnotationComposer a) f,
  ) {
    final $$FavoriteTagLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteTagLinks,
      getReferencedColumn: (t) => t.favoriteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTagLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteTagLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          FavoriteRow,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (FavoriteRow, $$FavoritesTableReferences),
          FavoriteRow,
          PrefetchHooks Function({bool playlistId, bool favoriteTagLinksRefs})
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<ItemType> itemType = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int?> customIndex = const Value.absent(),
              }) => FavoritesCompanion(
                id: id,
                playlistId: playlistId,
                itemType: itemType,
                providerId: providerId,
                addedAt: addedAt,
                customIndex: customIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required ItemType itemType,
                required String providerId,
                required DateTime addedAt,
                Value<int?> customIndex = const Value.absent(),
              }) => FavoritesCompanion.insert(
                id: id,
                playlistId: playlistId,
                itemType: itemType,
                providerId: providerId,
                addedAt: addedAt,
                customIndex: customIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoritesTable, FavoriteRow>(table),
                  $$FavoritesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({playlistId = false, favoriteTagLinksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (favoriteTagLinksRefs) db.favoriteTagLinks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (playlistId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.playlistId,
                            referencedTable: $$FavoritesTableReferences
                                ._playlistIdTable(db),
                            referencedColumn: $$FavoritesTableReferences
                                ._playlistIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (favoriteTagLinksRefs)
                        await $_getPrefetchedData<
                          FavoriteRow,
                          $FavoritesTable,
                          FavoriteTagLinkRow
                        >(
                          currentTable: table,
                          referencedTable: $$FavoritesTableReferences
                              ._favoriteTagLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FavoritesTableReferences(
                                db,
                                table,
                                p0,
                              ).favoriteTagLinksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.favoriteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      FavoriteRow,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (FavoriteRow, $$FavoritesTableReferences),
      FavoriteRow,
      PrefetchHooks Function({bool playlistId, bool favoriteTagLinksRefs})
    >;
typedef $$FavoriteTagsTableCreateCompanionBuilder =
    FavoriteTagsCompanion Function({
      Value<int> id,
      required int playlistId,
      required String name,
      Value<int> sortIndex,
    });
typedef $$FavoriteTagsTableUpdateCompanionBuilder =
    FavoriteTagsCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<String> name,
      Value<int> sortIndex,
    });

final class $$FavoriteTagsTableReferences
    extends BaseReferences<_$AppDatabase, $FavoriteTagsTable, FavoriteTagRow> {
  $$FavoriteTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('favorite_tags__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FavoriteTagLinksTable, List<FavoriteTagLinkRow>>
  _favoriteTagLinksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favoriteTagLinks,
    aliasName: 'favorite_tags__id__favorite_tag_links__tag_id',
  );

  $$FavoriteTagLinksTableProcessedTableManager get favoriteTagLinksRefs {
    final manager = $$FavoriteTagLinksTableTableManager(
      $_db,
      $_db.favoriteTagLinks,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _favoriteTagLinksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FavoriteTagsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteTagsTable> {
  $$FavoriteTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> favoriteTagLinksRefs(
    Expression<bool> Function($$FavoriteTagLinksTableFilterComposer f) f,
  ) {
    final $$FavoriteTagLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteTagLinks,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTagLinksTableFilterComposer(
            $db: $db,
            $table: $db.favoriteTagLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FavoriteTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteTagsTable> {
  $$FavoriteTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteTagsTable> {
  $$FavoriteTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> favoriteTagLinksRefs<T extends Object>(
    Expression<T> Function($$FavoriteTagLinksTableAnnotationComposer a) f,
  ) {
    final $$FavoriteTagLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favoriteTagLinks,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTagLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteTagLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FavoriteTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteTagsTable,
          FavoriteTagRow,
          $$FavoriteTagsTableFilterComposer,
          $$FavoriteTagsTableOrderingComposer,
          $$FavoriteTagsTableAnnotationComposer,
          $$FavoriteTagsTableCreateCompanionBuilder,
          $$FavoriteTagsTableUpdateCompanionBuilder,
          (FavoriteTagRow, $$FavoriteTagsTableReferences),
          FavoriteTagRow,
          PrefetchHooks Function({bool playlistId, bool favoriteTagLinksRefs})
        > {
  $$FavoriteTagsTableTableManager(_$AppDatabase db, $FavoriteTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
              }) => FavoriteTagsCompanion(
                id: id,
                playlistId: playlistId,
                name: name,
                sortIndex: sortIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String name,
                Value<int> sortIndex = const Value.absent(),
              }) => FavoriteTagsCompanion.insert(
                id: id,
                playlistId: playlistId,
                name: name,
                sortIndex: sortIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoriteTagsTable, FavoriteTagRow>(table),
                  $$FavoriteTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({playlistId = false, favoriteTagLinksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (favoriteTagLinksRefs) db.favoriteTagLinks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (playlistId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.playlistId,
                            referencedTable: $$FavoriteTagsTableReferences
                                ._playlistIdTable(db),
                            referencedColumn: $$FavoriteTagsTableReferences
                                ._playlistIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (favoriteTagLinksRefs)
                        await $_getPrefetchedData<
                          FavoriteTagRow,
                          $FavoriteTagsTable,
                          FavoriteTagLinkRow
                        >(
                          currentTable: table,
                          referencedTable: $$FavoriteTagsTableReferences
                              ._favoriteTagLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FavoriteTagsTableReferences(
                                db,
                                table,
                                p0,
                              ).favoriteTagLinksRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.tagId == item.id),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FavoriteTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteTagsTable,
      FavoriteTagRow,
      $$FavoriteTagsTableFilterComposer,
      $$FavoriteTagsTableOrderingComposer,
      $$FavoriteTagsTableAnnotationComposer,
      $$FavoriteTagsTableCreateCompanionBuilder,
      $$FavoriteTagsTableUpdateCompanionBuilder,
      (FavoriteTagRow, $$FavoriteTagsTableReferences),
      FavoriteTagRow,
      PrefetchHooks Function({bool playlistId, bool favoriteTagLinksRefs})
    >;
typedef $$FavoriteTagLinksTableCreateCompanionBuilder =
    FavoriteTagLinksCompanion Function({
      required int favoriteId,
      required int tagId,
      Value<int> rowid,
    });
typedef $$FavoriteTagLinksTableUpdateCompanionBuilder =
    FavoriteTagLinksCompanion Function({
      Value<int> favoriteId,
      Value<int> tagId,
      Value<int> rowid,
    });

final class $$FavoriteTagLinksTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FavoriteTagLinksTable,
          FavoriteTagLinkRow
        > {
  $$FavoriteTagLinksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FavoritesTable _favoriteIdTable(_$AppDatabase db) => db.favorites
      .createAlias('favorite_tag_links__favorite_id__favorites__id');

  $$FavoritesTableProcessedTableManager get favoriteId {
    final $_column = $_itemColumn<int>('favorite_id')!;

    final manager = $$FavoritesTableTableManager(
      $_db,
      $_db.favorites,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_favoriteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FavoriteTagsTable _tagIdTable(_$AppDatabase db) => db.favoriteTags
      .createAlias('favorite_tag_links__tag_id__favorite_tags__id');

  $$FavoriteTagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$FavoriteTagsTableTableManager(
      $_db,
      $_db.favoriteTags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoriteTagLinksTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteTagLinksTable> {
  $$FavoriteTagLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$FavoritesTableFilterComposer get favoriteId {
    final $$FavoritesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.favoriteId,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableFilterComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FavoriteTagsTableFilterComposer get tagId {
    final $$FavoriteTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.favoriteTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTagsTableFilterComposer(
            $db: $db,
            $table: $db.favoriteTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteTagLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteTagLinksTable> {
  $$FavoriteTagLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$FavoritesTableOrderingComposer get favoriteId {
    final $$FavoritesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.favoriteId,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableOrderingComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FavoriteTagsTableOrderingComposer get tagId {
    final $$FavoriteTagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.favoriteTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTagsTableOrderingComposer(
            $db: $db,
            $table: $db.favoriteTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteTagLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteTagLinksTable> {
  $$FavoriteTagLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$FavoritesTableAnnotationComposer get favoriteId {
    final $$FavoritesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.favoriteId,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableAnnotationComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FavoriteTagsTableAnnotationComposer get tagId {
    final $$FavoriteTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.favoriteTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.favoriteTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteTagLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteTagLinksTable,
          FavoriteTagLinkRow,
          $$FavoriteTagLinksTableFilterComposer,
          $$FavoriteTagLinksTableOrderingComposer,
          $$FavoriteTagLinksTableAnnotationComposer,
          $$FavoriteTagLinksTableCreateCompanionBuilder,
          $$FavoriteTagLinksTableUpdateCompanionBuilder,
          (FavoriteTagLinkRow, $$FavoriteTagLinksTableReferences),
          FavoriteTagLinkRow,
          PrefetchHooks Function({bool favoriteId, bool tagId})
        > {
  $$FavoriteTagLinksTableTableManager(
    _$AppDatabase db,
    $FavoriteTagLinksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteTagLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteTagLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteTagLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> favoriteId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteTagLinksCompanion(
                favoriteId: favoriteId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int favoriteId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => FavoriteTagLinksCompanion.insert(
                favoriteId: favoriteId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoriteTagLinksTable, FavoriteTagLinkRow>(
                    table,
                  ),
                  $$FavoriteTagLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({favoriteId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (favoriteId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.favoriteId,
                        referencedTable: $$FavoriteTagLinksTableReferences
                            ._favoriteIdTable(db),
                        referencedColumn: $$FavoriteTagLinksTableReferences
                            ._favoriteIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$FavoriteTagLinksTableReferences
                            ._tagIdTable(db),
                        referencedColumn: $$FavoriteTagLinksTableReferences
                            ._tagIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FavoriteTagLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteTagLinksTable,
      FavoriteTagLinkRow,
      $$FavoriteTagLinksTableFilterComposer,
      $$FavoriteTagLinksTableOrderingComposer,
      $$FavoriteTagLinksTableAnnotationComposer,
      $$FavoriteTagLinksTableCreateCompanionBuilder,
      $$FavoriteTagLinksTableUpdateCompanionBuilder,
      (FavoriteTagLinkRow, $$FavoriteTagLinksTableReferences),
      FavoriteTagLinkRow,
      PrefetchHooks Function({bool favoriteId, bool tagId})
    >;
typedef $$WatchStatesTableCreateCompanionBuilder =
    WatchStatesCompanion Function({
      required int playlistId,
      required ItemType itemType,
      required String providerId,
      Value<String?> seriesId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<bool> watched,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WatchStatesTableUpdateCompanionBuilder =
    WatchStatesCompanion Function({
      Value<int> playlistId,
      Value<ItemType> itemType,
      Value<String> providerId,
      Value<String?> seriesId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<bool> watched,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WatchStatesTableReferences
    extends BaseReferences<_$AppDatabase, $WatchStatesTable, WatchStateRow> {
  $$WatchStatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('watch_states__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WatchStatesTableFilterComposer
    extends Composer<_$AppDatabase, $WatchStatesTable> {
  $$WatchStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<ItemType, ItemType, int> get itemType =>
      $composableBuilder(
        column: $table.itemType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get watched => $composableBuilder(
    column: $table.watched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchStatesTable> {
  $$WatchStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get watched => $composableBuilder(
    column: $table.watched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchStatesTable> {
  $$WatchStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<ItemType, int> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get watched =>
      $composableBuilder(column: $table.watched, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchStatesTable,
          WatchStateRow,
          $$WatchStatesTableFilterComposer,
          $$WatchStatesTableOrderingComposer,
          $$WatchStatesTableAnnotationComposer,
          $$WatchStatesTableCreateCompanionBuilder,
          $$WatchStatesTableUpdateCompanionBuilder,
          (WatchStateRow, $$WatchStatesTableReferences),
          WatchStateRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$WatchStatesTableTableManager(_$AppDatabase db, $WatchStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<ItemType> itemType = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<bool> watched = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchStatesCompanion(
                playlistId: playlistId,
                itemType: itemType,
                providerId: providerId,
                seriesId: seriesId,
                positionMs: positionMs,
                durationMs: durationMs,
                watched: watched,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required ItemType itemType,
                required String providerId,
                Value<String?> seriesId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<bool> watched = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WatchStatesCompanion.insert(
                playlistId: playlistId,
                itemType: itemType,
                providerId: providerId,
                seriesId: seriesId,
                positionMs: positionMs,
                durationMs: durationMs,
                watched: watched,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WatchStatesTable, WatchStateRow>(table),
                  $$WatchStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$WatchStatesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$WatchStatesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WatchStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchStatesTable,
      WatchStateRow,
      $$WatchStatesTableFilterComposer,
      $$WatchStatesTableOrderingComposer,
      $$WatchStatesTableAnnotationComposer,
      $$WatchStatesTableCreateCompanionBuilder,
      $$WatchStatesTableUpdateCompanionBuilder,
      (WatchStateRow, $$WatchStatesTableReferences),
      WatchStateRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$LastWatchedLiveTableCreateCompanionBuilder =
    LastWatchedLiveCompanion Function({
      required int playlistId,
      required String channelId,
      required DateTime watchedAt,
      Value<int> rowid,
    });
typedef $$LastWatchedLiveTableUpdateCompanionBuilder =
    LastWatchedLiveCompanion Function({
      Value<int> playlistId,
      Value<String> channelId,
      Value<DateTime> watchedAt,
      Value<int> rowid,
    });

final class $$LastWatchedLiveTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LastWatchedLiveTable,
          LastWatchedLiveRow
        > {
  $$LastWatchedLiveTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('last_watched_live__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LastWatchedLiveTableFilterComposer
    extends Composer<_$AppDatabase, $LastWatchedLiveTable> {
  $$LastWatchedLiveTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LastWatchedLiveTableOrderingComposer
    extends Composer<_$AppDatabase, $LastWatchedLiveTable> {
  $$LastWatchedLiveTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LastWatchedLiveTableAnnotationComposer
    extends Composer<_$AppDatabase, $LastWatchedLiveTable> {
  $$LastWatchedLiveTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<DateTime> get watchedAt =>
      $composableBuilder(column: $table.watchedAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LastWatchedLiveTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LastWatchedLiveTable,
          LastWatchedLiveRow,
          $$LastWatchedLiveTableFilterComposer,
          $$LastWatchedLiveTableOrderingComposer,
          $$LastWatchedLiveTableAnnotationComposer,
          $$LastWatchedLiveTableCreateCompanionBuilder,
          $$LastWatchedLiveTableUpdateCompanionBuilder,
          (LastWatchedLiveRow, $$LastWatchedLiveTableReferences),
          LastWatchedLiveRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$LastWatchedLiveTableTableManager(
    _$AppDatabase db,
    $LastWatchedLiveTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LastWatchedLiveTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LastWatchedLiveTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LastWatchedLiveTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<DateTime> watchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LastWatchedLiveCompanion(
                playlistId: playlistId,
                channelId: channelId,
                watchedAt: watchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required String channelId,
                required DateTime watchedAt,
                Value<int> rowid = const Value.absent(),
              }) => LastWatchedLiveCompanion.insert(
                playlistId: playlistId,
                channelId: channelId,
                watchedAt: watchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LastWatchedLiveTable, LastWatchedLiveRow>(table),
                  $$LastWatchedLiveTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$LastWatchedLiveTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$LastWatchedLiveTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LastWatchedLiveTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LastWatchedLiveTable,
      LastWatchedLiveRow,
      $$LastWatchedLiveTableFilterComposer,
      $$LastWatchedLiveTableOrderingComposer,
      $$LastWatchedLiveTableAnnotationComposer,
      $$LastWatchedLiveTableCreateCompanionBuilder,
      $$LastWatchedLiveTableUpdateCompanionBuilder,
      (LastWatchedLiveRow, $$LastWatchedLiveTableReferences),
      LastWatchedLiveRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  Value<int> id,
  required int playlistId,
  required String channelId,
  required String channelName,
  Value<String?> epgChannelId,
  required String title,
  required int start,
  required int stop,
  Value<bool> fired,
  required DateTime createdAt,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<int> id,
  Value<int> playlistId,
  Value<String> channelId,
  Value<String> channelName,
  Value<String?> epgChannelId,
  Value<String> title,
  Value<int> start,
  Value<int> stop,
  Value<bool> fired,
  Value<DateTime> createdAt,
});

final class $$RemindersTableReferences
    extends BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('reminders__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stop => $composableBuilder(
    column: $table.stop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fired => $composableBuilder(
    column: $table.fired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stop => $composableBuilder(
    column: $table.stop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fired => $composableBuilder(
    column: $table.fired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get epgChannelId => $composableBuilder(
    column: $table.epgChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<int> get stop =>
      $composableBuilder(column: $table.stop, builder: (column) => column);

  GeneratedColumn<bool> get fired =>
      $composableBuilder(column: $table.fired, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (ReminderRow, $$RemindersTableReferences),
          ReminderRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<String> channelName = const Value.absent(),
                Value<String?> epgChannelId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> start = const Value.absent(),
                Value<int> stop = const Value.absent(),
                Value<bool> fired = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                playlistId: playlistId,
                channelId: channelId,
                channelName: channelName,
                epgChannelId: epgChannelId,
                title: title,
                start: start,
                stop: stop,
                fired: fired,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String channelId,
                required String channelName,
                Value<String?> epgChannelId = const Value.absent(),
                required String title,
                required int start,
                required int stop,
                Value<bool> fired = const Value.absent(),
                required DateTime createdAt,
              }) => RemindersCompanion.insert(
                id: id,
                playlistId: playlistId,
                channelId: channelId,
                channelName: channelName,
                epgChannelId: epgChannelId,
                title: title,
                start: start,
                stop: stop,
                fired: fired,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, ReminderRow>(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$RemindersTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$RemindersTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (ReminderRow, $$RemindersTableReferences),
      ReminderRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$DownloadsTableCreateCompanionBuilder = DownloadsCompanion Function({
  Value<int> id,
  Value<int?> playlistId,
  required ItemType itemType,
  required String providerId,
  required String title,
  required String url,
  required String filePath,
  required DownloadStatus status,
  Value<int> bytesTotal,
  Value<int> bytesDone,
  Value<String?> error,
  required DateTime createdAt,
});
typedef $$DownloadsTableUpdateCompanionBuilder = DownloadsCompanion Function({
  Value<int> id,
  Value<int?> playlistId,
  Value<ItemType> itemType,
  Value<String> providerId,
  Value<String> title,
  Value<String> url,
  Value<String> filePath,
  Value<DownloadStatus> status,
  Value<int> bytesTotal,
  Value<int> bytesDone,
  Value<String?> error,
  Value<DateTime> createdAt,
});

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ItemType, ItemType, int> get itemType =>
      $composableBuilder(
        column: $table.itemType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadStatus, DownloadStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesDone => $composableBuilder(
    column: $table.bytesDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesDone => $composableBuilder(
    column: $table.bytesDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ItemType, int> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytesDone =>
      $composableBuilder(column: $table.bytesDone, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          DownloadRow,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (
            DownloadRow,
            BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>,
          ),
          DownloadRow,
          PrefetchHooks Function()
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> playlistId = const Value.absent(),
                Value<ItemType> itemType = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<DownloadStatus> status = const Value.absent(),
                Value<int> bytesTotal = const Value.absent(),
                Value<int> bytesDone = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DownloadsCompanion(
                id: id,
                playlistId: playlistId,
                itemType: itemType,
                providerId: providerId,
                title: title,
                url: url,
                filePath: filePath,
                status: status,
                bytesTotal: bytesTotal,
                bytesDone: bytesDone,
                error: error,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> playlistId = const Value.absent(),
                required ItemType itemType,
                required String providerId,
                required String title,
                required String url,
                required String filePath,
                required DownloadStatus status,
                Value<int> bytesTotal = const Value.absent(),
                Value<int> bytesDone = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required DateTime createdAt,
              }) => DownloadsCompanion.insert(
                id: id,
                playlistId: playlistId,
                itemType: itemType,
                providerId: providerId,
                title: title,
                url: url,
                filePath: filePath,
                status: status,
                bytesTotal: bytesTotal,
                bytesDone: bytesDone,
                error: error,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadsTable, DownloadRow>(table),
                  BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      DownloadRow,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (
        DownloadRow,
        BaseReferences<_$AppDatabase, $DownloadsTable, DownloadRow>,
      ),
      DownloadRow,
      PrefetchHooks Function()
    >;
typedef $$RecordingsTableCreateCompanionBuilder = RecordingsCompanion Function({
  Value<int> id,
  Value<int?> playlistId,
  required String channelId,
  required String channelName,
  required String title,
  required String filePath,
  required DateTime startedAt,
  Value<DateTime?> endsAt,
  required DownloadStatus status,
});
typedef $$RecordingsTableUpdateCompanionBuilder = RecordingsCompanion Function({
  Value<int> id,
  Value<int?> playlistId,
  Value<String> channelId,
  Value<String> channelName,
  Value<String> title,
  Value<String> filePath,
  Value<DateTime> startedAt,
  Value<DateTime?> endsAt,
  Value<DownloadStatus> status,
});

class $$RecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadStatus, DownloadStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$RecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DownloadStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$RecordingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordingsTable,
          RecordingRow,
          $$RecordingsTableFilterComposer,
          $$RecordingsTableOrderingComposer,
          $$RecordingsTableAnnotationComposer,
          $$RecordingsTableCreateCompanionBuilder,
          $$RecordingsTableUpdateCompanionBuilder,
          (
            RecordingRow,
            BaseReferences<_$AppDatabase, $RecordingsTable, RecordingRow>,
          ),
          RecordingRow,
          PrefetchHooks Function()
        > {
  $$RecordingsTableTableManager(_$AppDatabase db, $RecordingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> playlistId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<String> channelName = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                Value<DownloadStatus> status = const Value.absent(),
              }) => RecordingsCompanion(
                id: id,
                playlistId: playlistId,
                channelId: channelId,
                channelName: channelName,
                title: title,
                filePath: filePath,
                startedAt: startedAt,
                endsAt: endsAt,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> playlistId = const Value.absent(),
                required String channelId,
                required String channelName,
                required String title,
                required String filePath,
                required DateTime startedAt,
                Value<DateTime?> endsAt = const Value.absent(),
                required DownloadStatus status,
              }) => RecordingsCompanion.insert(
                id: id,
                playlistId: playlistId,
                channelId: channelId,
                channelName: channelName,
                title: title,
                filePath: filePath,
                startedAt: startedAt,
                endsAt: endsAt,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordingsTable, RecordingRow>(table),
                  BaseReferences<_$AppDatabase, $RecordingsTable, RecordingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordingsTable,
      RecordingRow,
      $$RecordingsTableFilterComposer,
      $$RecordingsTableOrderingComposer,
      $$RecordingsTableAnnotationComposer,
      $$RecordingsTableCreateCompanionBuilder,
      $$RecordingsTableUpdateCompanionBuilder,
      (
        RecordingRow,
        BaseReferences<_$AppDatabase, $RecordingsTable, RecordingRow>,
      ),
      RecordingRow,
      PrefetchHooks Function()
    >;
typedef $$TmdbCacheTableCreateCompanionBuilder = TmdbCacheCompanion Function({
  required String cacheKey,
  required String json,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$TmdbCacheTableUpdateCompanionBuilder = TmdbCacheCompanion Function({
  Value<String> cacheKey,
  Value<String> json,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$TmdbCacheTableFilterComposer
    extends Composer<_$AppDatabase, $TmdbCacheTable> {
  $$TmdbCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TmdbCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $TmdbCacheTable> {
  $$TmdbCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TmdbCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $TmdbCacheTable> {
  $$TmdbCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$TmdbCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TmdbCacheTable,
          TmdbCacheRow,
          $$TmdbCacheTableFilterComposer,
          $$TmdbCacheTableOrderingComposer,
          $$TmdbCacheTableAnnotationComposer,
          $$TmdbCacheTableCreateCompanionBuilder,
          $$TmdbCacheTableUpdateCompanionBuilder,
          (
            TmdbCacheRow,
            BaseReferences<_$AppDatabase, $TmdbCacheTable, TmdbCacheRow>,
          ),
          TmdbCacheRow,
          PrefetchHooks Function()
        > {
  $$TmdbCacheTableTableManager(_$AppDatabase db, $TmdbCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TmdbCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TmdbCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TmdbCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TmdbCacheCompanion(
                cacheKey: cacheKey,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String json,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => TmdbCacheCompanion.insert(
                cacheKey: cacheKey,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TmdbCacheTable, TmdbCacheRow>(table),
                  BaseReferences<_$AppDatabase, $TmdbCacheTable, TmdbCacheRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TmdbCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TmdbCacheTable,
      TmdbCacheRow,
      $$TmdbCacheTableFilterComposer,
      $$TmdbCacheTableOrderingComposer,
      $$TmdbCacheTableAnnotationComposer,
      $$TmdbCacheTableCreateCompanionBuilder,
      $$TmdbCacheTableUpdateCompanionBuilder,
      (
        TmdbCacheRow,
        BaseReferences<_$AppDatabase, $TmdbCacheTable, TmdbCacheRow>,
      ),
      TmdbCacheRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String scope,
  required String key,
  required String json,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> scope,
  Value<String> key,
  Value<String> json,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                scope: scope,
                key: key,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String key,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                scope: scope,
                key: key,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $SearchIndexTableManager get searchIndex =>
      $SearchIndexTableManager(_db, _db.searchIndex);
  $ProgrammeSearchTableManager get programmeSearch =>
      $ProgrammeSearchTableManager(_db, _db.programmeSearch);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db, _db.channels);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db, _db.movies);
  $$SeriesTableTableManager get series =>
      $$SeriesTableTableManager(_db, _db.series);
  $$SeasonsTableTableManager get seasons =>
      $$SeasonsTableTableManager(_db, _db.seasons);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$EpgChannelsTableTableManager get epgChannels =>
      $$EpgChannelsTableTableManager(_db, _db.epgChannels);
  $$ProgrammesTableTableManager get programmes =>
      $$ProgrammesTableTableManager(_db, _db.programmes);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$FavoriteTagsTableTableManager get favoriteTags =>
      $$FavoriteTagsTableTableManager(_db, _db.favoriteTags);
  $$FavoriteTagLinksTableTableManager get favoriteTagLinks =>
      $$FavoriteTagLinksTableTableManager(_db, _db.favoriteTagLinks);
  $$WatchStatesTableTableManager get watchStates =>
      $$WatchStatesTableTableManager(_db, _db.watchStates);
  $$LastWatchedLiveTableTableManager get lastWatchedLive =>
      $$LastWatchedLiveTableTableManager(_db, _db.lastWatchedLive);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db, _db.recordings);
  $$TmdbCacheTableTableManager get tmdbCache =>
      $$TmdbCacheTableTableManager(_db, _db.tmdbCache);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
