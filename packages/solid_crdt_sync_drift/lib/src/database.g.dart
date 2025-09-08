// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RdfDocumentsTable extends RdfDocuments
    with TableInfo<$RdfDocumentsTable, RdfDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RdfDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIriMeta =
      const VerificationMeta('documentIri');
  @override
  late final GeneratedColumn<String> documentIri = GeneratedColumn<String>(
      'document_iri', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rdfContentMeta =
      const VerificationMeta('rdfContent');
  @override
  late final GeneratedColumn<String> rdfContent = GeneratedColumn<String>(
      'rdf_content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clockHashMeta =
      const VerificationMeta('clockHash');
  @override
  late final GeneratedColumn<String> clockHash = GeneratedColumn<String>(
      'clock_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastModifiedMeta =
      const VerificationMeta('lastModified');
  @override
  late final GeneratedColumn<DateTime> lastModified = GeneratedColumn<DateTime>(
      'last_modified', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  @override
  List<GeneratedColumn> get $columns =>
      [documentIri, rdfContent, clockHash, lastModified, syncStatus];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rdf_documents';
  @override
  VerificationContext validateIntegrity(Insertable<RdfDocument> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_iri')) {
      context.handle(
          _documentIriMeta,
          documentIri.isAcceptableOrUnknown(
              data['document_iri']!, _documentIriMeta));
    } else if (isInserting) {
      context.missing(_documentIriMeta);
    }
    if (data.containsKey('rdf_content')) {
      context.handle(
          _rdfContentMeta,
          rdfContent.isAcceptableOrUnknown(
              data['rdf_content']!, _rdfContentMeta));
    } else if (isInserting) {
      context.missing(_rdfContentMeta);
    }
    if (data.containsKey('clock_hash')) {
      context.handle(_clockHashMeta,
          clockHash.isAcceptableOrUnknown(data['clock_hash']!, _clockHashMeta));
    } else if (isInserting) {
      context.missing(_clockHashMeta);
    }
    if (data.containsKey('last_modified')) {
      context.handle(
          _lastModifiedMeta,
          lastModified.isAcceptableOrUnknown(
              data['last_modified']!, _lastModifiedMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentIri};
  @override
  RdfDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RdfDocument(
      documentIri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}document_iri'])!,
      rdfContent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rdf_content'])!,
      clockHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}clock_hash'])!,
      lastModified: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_modified'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
    );
  }

  @override
  $RdfDocumentsTable createAlias(String alias) {
    return $RdfDocumentsTable(attachedDatabase, alias);
  }
}

class RdfDocument extends DataClass implements Insertable<RdfDocument> {
  /// Document IRI (primary key)
  final String documentIri;

  /// Full RDF content as text
  final String rdfContent;

  /// Hybrid Logical Clock hash for change detection
  final String clockHash;

  /// Last modified timestamp
  final DateTime lastModified;

  /// Sync status (pending, synced, conflict)
  final String syncStatus;
  const RdfDocument(
      {required this.documentIri,
      required this.rdfContent,
      required this.clockHash,
      required this.lastModified,
      required this.syncStatus});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_iri'] = Variable<String>(documentIri);
    map['rdf_content'] = Variable<String>(rdfContent);
    map['clock_hash'] = Variable<String>(clockHash);
    map['last_modified'] = Variable<DateTime>(lastModified);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  RdfDocumentsCompanion toCompanion(bool nullToAbsent) {
    return RdfDocumentsCompanion(
      documentIri: Value(documentIri),
      rdfContent: Value(rdfContent),
      clockHash: Value(clockHash),
      lastModified: Value(lastModified),
      syncStatus: Value(syncStatus),
    );
  }

  factory RdfDocument.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RdfDocument(
      documentIri: serializer.fromJson<String>(json['documentIri']),
      rdfContent: serializer.fromJson<String>(json['rdfContent']),
      clockHash: serializer.fromJson<String>(json['clockHash']),
      lastModified: serializer.fromJson<DateTime>(json['lastModified']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentIri': serializer.toJson<String>(documentIri),
      'rdfContent': serializer.toJson<String>(rdfContent),
      'clockHash': serializer.toJson<String>(clockHash),
      'lastModified': serializer.toJson<DateTime>(lastModified),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  RdfDocument copyWith(
          {String? documentIri,
          String? rdfContent,
          String? clockHash,
          DateTime? lastModified,
          String? syncStatus}) =>
      RdfDocument(
        documentIri: documentIri ?? this.documentIri,
        rdfContent: rdfContent ?? this.rdfContent,
        clockHash: clockHash ?? this.clockHash,
        lastModified: lastModified ?? this.lastModified,
        syncStatus: syncStatus ?? this.syncStatus,
      );
  RdfDocument copyWithCompanion(RdfDocumentsCompanion data) {
    return RdfDocument(
      documentIri:
          data.documentIri.present ? data.documentIri.value : this.documentIri,
      rdfContent:
          data.rdfContent.present ? data.rdfContent.value : this.rdfContent,
      clockHash: data.clockHash.present ? data.clockHash.value : this.clockHash,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RdfDocument(')
          ..write('documentIri: $documentIri, ')
          ..write('rdfContent: $rdfContent, ')
          ..write('clockHash: $clockHash, ')
          ..write('lastModified: $lastModified, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(documentIri, rdfContent, clockHash, lastModified, syncStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RdfDocument &&
          other.documentIri == this.documentIri &&
          other.rdfContent == this.rdfContent &&
          other.clockHash == this.clockHash &&
          other.lastModified == this.lastModified &&
          other.syncStatus == this.syncStatus);
}

class RdfDocumentsCompanion extends UpdateCompanion<RdfDocument> {
  final Value<String> documentIri;
  final Value<String> rdfContent;
  final Value<String> clockHash;
  final Value<DateTime> lastModified;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const RdfDocumentsCompanion({
    this.documentIri = const Value.absent(),
    this.rdfContent = const Value.absent(),
    this.clockHash = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RdfDocumentsCompanion.insert({
    required String documentIri,
    required String rdfContent,
    required String clockHash,
    this.lastModified = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : documentIri = Value(documentIri),
        rdfContent = Value(rdfContent),
        clockHash = Value(clockHash);
  static Insertable<RdfDocument> custom({
    Expression<String>? documentIri,
    Expression<String>? rdfContent,
    Expression<String>? clockHash,
    Expression<DateTime>? lastModified,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentIri != null) 'document_iri': documentIri,
      if (rdfContent != null) 'rdf_content': rdfContent,
      if (clockHash != null) 'clock_hash': clockHash,
      if (lastModified != null) 'last_modified': lastModified,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RdfDocumentsCompanion copyWith(
      {Value<String>? documentIri,
      Value<String>? rdfContent,
      Value<String>? clockHash,
      Value<DateTime>? lastModified,
      Value<String>? syncStatus,
      Value<int>? rowid}) {
    return RdfDocumentsCompanion(
      documentIri: documentIri ?? this.documentIri,
      rdfContent: rdfContent ?? this.rdfContent,
      clockHash: clockHash ?? this.clockHash,
      lastModified: lastModified ?? this.lastModified,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentIri.present) {
      map['document_iri'] = Variable<String>(documentIri.value);
    }
    if (rdfContent.present) {
      map['rdf_content'] = Variable<String>(rdfContent.value);
    }
    if (clockHash.present) {
      map['clock_hash'] = Variable<String>(clockHash.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<DateTime>(lastModified.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RdfDocumentsCompanion(')
          ..write('documentIri: $documentIri, ')
          ..write('rdfContent: $rdfContent, ')
          ..write('clockHash: $clockHash, ')
          ..write('lastModified: $lastModified, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RdfTriplesTable extends RdfTriples
    with TableInfo<$RdfTriplesTable, RdfTriple> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RdfTriplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _subjectMeta =
      const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
      'subject', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _predicateMeta =
      const VerificationMeta('predicate');
  @override
  late final GeneratedColumn<String> predicate = GeneratedColumn<String>(
      'predicate', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _objectMeta = const VerificationMeta('object');
  @override
  late final GeneratedColumn<String> object = GeneratedColumn<String>(
      'object', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _objectTypeMeta =
      const VerificationMeta('objectType');
  @override
  late final GeneratedColumn<String> objectType = GeneratedColumn<String>(
      'object_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _objectLangMeta =
      const VerificationMeta('objectLang');
  @override
  late final GeneratedColumn<String> objectLang = GeneratedColumn<String>(
      'object_lang', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _documentIriMeta =
      const VerificationMeta('documentIri');
  @override
  late final GeneratedColumn<String> documentIri = GeneratedColumn<String>(
      'document_iri', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES rdf_documents (document_iri)'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, subject, predicate, object, objectType, objectLang, documentIri];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rdf_triples';
  @override
  VerificationContext validateIntegrity(Insertable<RdfTriple> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta,
          subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('predicate')) {
      context.handle(_predicateMeta,
          predicate.isAcceptableOrUnknown(data['predicate']!, _predicateMeta));
    } else if (isInserting) {
      context.missing(_predicateMeta);
    }
    if (data.containsKey('object')) {
      context.handle(_objectMeta,
          object.isAcceptableOrUnknown(data['object']!, _objectMeta));
    } else if (isInserting) {
      context.missing(_objectMeta);
    }
    if (data.containsKey('object_type')) {
      context.handle(
          _objectTypeMeta,
          objectType.isAcceptableOrUnknown(
              data['object_type']!, _objectTypeMeta));
    }
    if (data.containsKey('object_lang')) {
      context.handle(
          _objectLangMeta,
          objectLang.isAcceptableOrUnknown(
              data['object_lang']!, _objectLangMeta));
    }
    if (data.containsKey('document_iri')) {
      context.handle(
          _documentIriMeta,
          documentIri.isAcceptableOrUnknown(
              data['document_iri']!, _documentIriMeta));
    } else if (isInserting) {
      context.missing(_documentIriMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RdfTriple map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RdfTriple(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      subject: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject'])!,
      predicate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}predicate'])!,
      object: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}object'])!,
      objectType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}object_type']),
      objectLang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}object_lang']),
      documentIri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}document_iri'])!,
    );
  }

  @override
  $RdfTriplesTable createAlias(String alias) {
    return $RdfTriplesTable(attachedDatabase, alias);
  }
}

class RdfTriple extends DataClass implements Insertable<RdfTriple> {
  /// Auto-incrementing ID
  final int id;

  /// Subject IRI or blank node
  final String subject;

  /// Predicate IRI
  final String predicate;

  /// Object value (IRI, literal, or blank node)
  final String object;

  /// Object datatype (for literals)
  final String? objectType;

  /// Language tag (for literals)
  final String? objectLang;

  /// Source document IRI
  final String documentIri;
  const RdfTriple(
      {required this.id,
      required this.subject,
      required this.predicate,
      required this.object,
      this.objectType,
      this.objectLang,
      required this.documentIri});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject'] = Variable<String>(subject);
    map['predicate'] = Variable<String>(predicate);
    map['object'] = Variable<String>(object);
    if (!nullToAbsent || objectType != null) {
      map['object_type'] = Variable<String>(objectType);
    }
    if (!nullToAbsent || objectLang != null) {
      map['object_lang'] = Variable<String>(objectLang);
    }
    map['document_iri'] = Variable<String>(documentIri);
    return map;
  }

  RdfTriplesCompanion toCompanion(bool nullToAbsent) {
    return RdfTriplesCompanion(
      id: Value(id),
      subject: Value(subject),
      predicate: Value(predicate),
      object: Value(object),
      objectType: objectType == null && nullToAbsent
          ? const Value.absent()
          : Value(objectType),
      objectLang: objectLang == null && nullToAbsent
          ? const Value.absent()
          : Value(objectLang),
      documentIri: Value(documentIri),
    );
  }

  factory RdfTriple.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RdfTriple(
      id: serializer.fromJson<int>(json['id']),
      subject: serializer.fromJson<String>(json['subject']),
      predicate: serializer.fromJson<String>(json['predicate']),
      object: serializer.fromJson<String>(json['object']),
      objectType: serializer.fromJson<String?>(json['objectType']),
      objectLang: serializer.fromJson<String?>(json['objectLang']),
      documentIri: serializer.fromJson<String>(json['documentIri']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subject': serializer.toJson<String>(subject),
      'predicate': serializer.toJson<String>(predicate),
      'object': serializer.toJson<String>(object),
      'objectType': serializer.toJson<String?>(objectType),
      'objectLang': serializer.toJson<String?>(objectLang),
      'documentIri': serializer.toJson<String>(documentIri),
    };
  }

  RdfTriple copyWith(
          {int? id,
          String? subject,
          String? predicate,
          String? object,
          Value<String?> objectType = const Value.absent(),
          Value<String?> objectLang = const Value.absent(),
          String? documentIri}) =>
      RdfTriple(
        id: id ?? this.id,
        subject: subject ?? this.subject,
        predicate: predicate ?? this.predicate,
        object: object ?? this.object,
        objectType: objectType.present ? objectType.value : this.objectType,
        objectLang: objectLang.present ? objectLang.value : this.objectLang,
        documentIri: documentIri ?? this.documentIri,
      );
  RdfTriple copyWithCompanion(RdfTriplesCompanion data) {
    return RdfTriple(
      id: data.id.present ? data.id.value : this.id,
      subject: data.subject.present ? data.subject.value : this.subject,
      predicate: data.predicate.present ? data.predicate.value : this.predicate,
      object: data.object.present ? data.object.value : this.object,
      objectType:
          data.objectType.present ? data.objectType.value : this.objectType,
      objectLang:
          data.objectLang.present ? data.objectLang.value : this.objectLang,
      documentIri:
          data.documentIri.present ? data.documentIri.value : this.documentIri,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RdfTriple(')
          ..write('id: $id, ')
          ..write('subject: $subject, ')
          ..write('predicate: $predicate, ')
          ..write('object: $object, ')
          ..write('objectType: $objectType, ')
          ..write('objectLang: $objectLang, ')
          ..write('documentIri: $documentIri')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, subject, predicate, object, objectType, objectLang, documentIri);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RdfTriple &&
          other.id == this.id &&
          other.subject == this.subject &&
          other.predicate == this.predicate &&
          other.object == this.object &&
          other.objectType == this.objectType &&
          other.objectLang == this.objectLang &&
          other.documentIri == this.documentIri);
}

class RdfTriplesCompanion extends UpdateCompanion<RdfTriple> {
  final Value<int> id;
  final Value<String> subject;
  final Value<String> predicate;
  final Value<String> object;
  final Value<String?> objectType;
  final Value<String?> objectLang;
  final Value<String> documentIri;
  const RdfTriplesCompanion({
    this.id = const Value.absent(),
    this.subject = const Value.absent(),
    this.predicate = const Value.absent(),
    this.object = const Value.absent(),
    this.objectType = const Value.absent(),
    this.objectLang = const Value.absent(),
    this.documentIri = const Value.absent(),
  });
  RdfTriplesCompanion.insert({
    this.id = const Value.absent(),
    required String subject,
    required String predicate,
    required String object,
    this.objectType = const Value.absent(),
    this.objectLang = const Value.absent(),
    required String documentIri,
  })  : subject = Value(subject),
        predicate = Value(predicate),
        object = Value(object),
        documentIri = Value(documentIri);
  static Insertable<RdfTriple> custom({
    Expression<int>? id,
    Expression<String>? subject,
    Expression<String>? predicate,
    Expression<String>? object,
    Expression<String>? objectType,
    Expression<String>? objectLang,
    Expression<String>? documentIri,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subject != null) 'subject': subject,
      if (predicate != null) 'predicate': predicate,
      if (object != null) 'object': object,
      if (objectType != null) 'object_type': objectType,
      if (objectLang != null) 'object_lang': objectLang,
      if (documentIri != null) 'document_iri': documentIri,
    });
  }

  RdfTriplesCompanion copyWith(
      {Value<int>? id,
      Value<String>? subject,
      Value<String>? predicate,
      Value<String>? object,
      Value<String?>? objectType,
      Value<String?>? objectLang,
      Value<String>? documentIri}) {
    return RdfTriplesCompanion(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      predicate: predicate ?? this.predicate,
      object: object ?? this.object,
      objectType: objectType ?? this.objectType,
      objectLang: objectLang ?? this.objectLang,
      documentIri: documentIri ?? this.documentIri,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (predicate.present) {
      map['predicate'] = Variable<String>(predicate.value);
    }
    if (object.present) {
      map['object'] = Variable<String>(object.value);
    }
    if (objectType.present) {
      map['object_type'] = Variable<String>(objectType.value);
    }
    if (objectLang.present) {
      map['object_lang'] = Variable<String>(objectLang.value);
    }
    if (documentIri.present) {
      map['document_iri'] = Variable<String>(documentIri.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RdfTriplesCompanion(')
          ..write('id: $id, ')
          ..write('subject: $subject, ')
          ..write('predicate: $predicate, ')
          ..write('object: $object, ')
          ..write('objectType: $objectType, ')
          ..write('objectLang: $objectLang, ')
          ..write('documentIri: $documentIri')
          ..write(')'))
        .toString();
  }
}

class $CrdtMetadataTable extends CrdtMetadata
    with TableInfo<$CrdtMetadataTable, CrdtMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrdtMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _resourceIriMeta =
      const VerificationMeta('resourceIri');
  @override
  late final GeneratedColumn<String> resourceIri = GeneratedColumn<String>(
      'resource_iri', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _installationIdMeta =
      const VerificationMeta('installationId');
  @override
  late final GeneratedColumn<String> installationId = GeneratedColumn<String>(
      'installation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _wallTimeMeta =
      const VerificationMeta('wallTime');
  @override
  late final GeneratedColumn<DateTime> wallTime = GeneratedColumn<DateTime>(
      'wall_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _logicalTimeMeta =
      const VerificationMeta('logicalTime');
  @override
  late final GeneratedColumn<int> logicalTime = GeneratedColumn<int>(
      'logical_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _tombstonesMeta =
      const VerificationMeta('tombstones');
  @override
  late final GeneratedColumn<String> tombstones = GeneratedColumn<String>(
      'tombstones', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [resourceIri, installationId, wallTime, logicalTime, tombstones];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'crdt_metadata';
  @override
  VerificationContext validateIntegrity(Insertable<CrdtMetadataData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('resource_iri')) {
      context.handle(
          _resourceIriMeta,
          resourceIri.isAcceptableOrUnknown(
              data['resource_iri']!, _resourceIriMeta));
    } else if (isInserting) {
      context.missing(_resourceIriMeta);
    }
    if (data.containsKey('installation_id')) {
      context.handle(
          _installationIdMeta,
          installationId.isAcceptableOrUnknown(
              data['installation_id']!, _installationIdMeta));
    } else if (isInserting) {
      context.missing(_installationIdMeta);
    }
    if (data.containsKey('wall_time')) {
      context.handle(_wallTimeMeta,
          wallTime.isAcceptableOrUnknown(data['wall_time']!, _wallTimeMeta));
    } else if (isInserting) {
      context.missing(_wallTimeMeta);
    }
    if (data.containsKey('logical_time')) {
      context.handle(
          _logicalTimeMeta,
          logicalTime.isAcceptableOrUnknown(
              data['logical_time']!, _logicalTimeMeta));
    } else if (isInserting) {
      context.missing(_logicalTimeMeta);
    }
    if (data.containsKey('tombstones')) {
      context.handle(
          _tombstonesMeta,
          tombstones.isAcceptableOrUnknown(
              data['tombstones']!, _tombstonesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {resourceIri, installationId};
  @override
  CrdtMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrdtMetadataData(
      resourceIri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_iri'])!,
      installationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}installation_id'])!,
      wallTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}wall_time'])!,
      logicalTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}logical_time'])!,
      tombstones: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tombstones']),
    );
  }

  @override
  $CrdtMetadataTable createAlias(String alias) {
    return $CrdtMetadataTable(attachedDatabase, alias);
  }
}

class CrdtMetadataData extends DataClass
    implements Insertable<CrdtMetadataData> {
  /// Resource IRI + installation ID (composite key)
  final String resourceIri;
  final String installationId;

  /// Hybrid Logical Clock components
  final DateTime wallTime;
  final int logicalTime;

  /// CRDT tombstones for deletions
  final String? tombstones;
  const CrdtMetadataData(
      {required this.resourceIri,
      required this.installationId,
      required this.wallTime,
      required this.logicalTime,
      this.tombstones});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['resource_iri'] = Variable<String>(resourceIri);
    map['installation_id'] = Variable<String>(installationId);
    map['wall_time'] = Variable<DateTime>(wallTime);
    map['logical_time'] = Variable<int>(logicalTime);
    if (!nullToAbsent || tombstones != null) {
      map['tombstones'] = Variable<String>(tombstones);
    }
    return map;
  }

  CrdtMetadataCompanion toCompanion(bool nullToAbsent) {
    return CrdtMetadataCompanion(
      resourceIri: Value(resourceIri),
      installationId: Value(installationId),
      wallTime: Value(wallTime),
      logicalTime: Value(logicalTime),
      tombstones: tombstones == null && nullToAbsent
          ? const Value.absent()
          : Value(tombstones),
    );
  }

  factory CrdtMetadataData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrdtMetadataData(
      resourceIri: serializer.fromJson<String>(json['resourceIri']),
      installationId: serializer.fromJson<String>(json['installationId']),
      wallTime: serializer.fromJson<DateTime>(json['wallTime']),
      logicalTime: serializer.fromJson<int>(json['logicalTime']),
      tombstones: serializer.fromJson<String?>(json['tombstones']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'resourceIri': serializer.toJson<String>(resourceIri),
      'installationId': serializer.toJson<String>(installationId),
      'wallTime': serializer.toJson<DateTime>(wallTime),
      'logicalTime': serializer.toJson<int>(logicalTime),
      'tombstones': serializer.toJson<String?>(tombstones),
    };
  }

  CrdtMetadataData copyWith(
          {String? resourceIri,
          String? installationId,
          DateTime? wallTime,
          int? logicalTime,
          Value<String?> tombstones = const Value.absent()}) =>
      CrdtMetadataData(
        resourceIri: resourceIri ?? this.resourceIri,
        installationId: installationId ?? this.installationId,
        wallTime: wallTime ?? this.wallTime,
        logicalTime: logicalTime ?? this.logicalTime,
        tombstones: tombstones.present ? tombstones.value : this.tombstones,
      );
  CrdtMetadataData copyWithCompanion(CrdtMetadataCompanion data) {
    return CrdtMetadataData(
      resourceIri:
          data.resourceIri.present ? data.resourceIri.value : this.resourceIri,
      installationId: data.installationId.present
          ? data.installationId.value
          : this.installationId,
      wallTime: data.wallTime.present ? data.wallTime.value : this.wallTime,
      logicalTime:
          data.logicalTime.present ? data.logicalTime.value : this.logicalTime,
      tombstones:
          data.tombstones.present ? data.tombstones.value : this.tombstones,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrdtMetadataData(')
          ..write('resourceIri: $resourceIri, ')
          ..write('installationId: $installationId, ')
          ..write('wallTime: $wallTime, ')
          ..write('logicalTime: $logicalTime, ')
          ..write('tombstones: $tombstones')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      resourceIri, installationId, wallTime, logicalTime, tombstones);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrdtMetadataData &&
          other.resourceIri == this.resourceIri &&
          other.installationId == this.installationId &&
          other.wallTime == this.wallTime &&
          other.logicalTime == this.logicalTime &&
          other.tombstones == this.tombstones);
}

class CrdtMetadataCompanion extends UpdateCompanion<CrdtMetadataData> {
  final Value<String> resourceIri;
  final Value<String> installationId;
  final Value<DateTime> wallTime;
  final Value<int> logicalTime;
  final Value<String?> tombstones;
  final Value<int> rowid;
  const CrdtMetadataCompanion({
    this.resourceIri = const Value.absent(),
    this.installationId = const Value.absent(),
    this.wallTime = const Value.absent(),
    this.logicalTime = const Value.absent(),
    this.tombstones = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CrdtMetadataCompanion.insert({
    required String resourceIri,
    required String installationId,
    required DateTime wallTime,
    required int logicalTime,
    this.tombstones = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : resourceIri = Value(resourceIri),
        installationId = Value(installationId),
        wallTime = Value(wallTime),
        logicalTime = Value(logicalTime);
  static Insertable<CrdtMetadataData> custom({
    Expression<String>? resourceIri,
    Expression<String>? installationId,
    Expression<DateTime>? wallTime,
    Expression<int>? logicalTime,
    Expression<String>? tombstones,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (resourceIri != null) 'resource_iri': resourceIri,
      if (installationId != null) 'installation_id': installationId,
      if (wallTime != null) 'wall_time': wallTime,
      if (logicalTime != null) 'logical_time': logicalTime,
      if (tombstones != null) 'tombstones': tombstones,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CrdtMetadataCompanion copyWith(
      {Value<String>? resourceIri,
      Value<String>? installationId,
      Value<DateTime>? wallTime,
      Value<int>? logicalTime,
      Value<String?>? tombstones,
      Value<int>? rowid}) {
    return CrdtMetadataCompanion(
      resourceIri: resourceIri ?? this.resourceIri,
      installationId: installationId ?? this.installationId,
      wallTime: wallTime ?? this.wallTime,
      logicalTime: logicalTime ?? this.logicalTime,
      tombstones: tombstones ?? this.tombstones,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (resourceIri.present) {
      map['resource_iri'] = Variable<String>(resourceIri.value);
    }
    if (installationId.present) {
      map['installation_id'] = Variable<String>(installationId.value);
    }
    if (wallTime.present) {
      map['wall_time'] = Variable<DateTime>(wallTime.value);
    }
    if (logicalTime.present) {
      map['logical_time'] = Variable<int>(logicalTime.value);
    }
    if (tombstones.present) {
      map['tombstones'] = Variable<String>(tombstones.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrdtMetadataCompanion(')
          ..write('resourceIri: $resourceIri, ')
          ..write('installationId: $installationId, ')
          ..write('wallTime: $wallTime, ')
          ..write('logicalTime: $logicalTime, ')
          ..write('tombstones: $tombstones, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IndexEntriesTable extends IndexEntries
    with TableInfo<$IndexEntriesTable, IndexEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IndexEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _indexIriMeta =
      const VerificationMeta('indexIri');
  @override
  late final GeneratedColumn<String> indexIri = GeneratedColumn<String>(
      'index_iri', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resourceIriMeta =
      const VerificationMeta('resourceIri');
  @override
  late final GeneratedColumn<String> resourceIri = GeneratedColumn<String>(
      'resource_iri', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resourceTypeMeta =
      const VerificationMeta('resourceType');
  @override
  late final GeneratedColumn<String> resourceType = GeneratedColumn<String>(
      'resource_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _headersMeta =
      const VerificationMeta('headers');
  @override
  late final GeneratedColumn<String> headers = GeneratedColumn<String>(
      'headers', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clockHashMeta =
      const VerificationMeta('clockHash');
  @override
  late final GeneratedColumn<String> clockHash = GeneratedColumn<String>(
      'clock_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [indexIri, resourceIri, resourceType, headers, clockHash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'index_entries';
  @override
  VerificationContext validateIntegrity(Insertable<IndexEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('index_iri')) {
      context.handle(_indexIriMeta,
          indexIri.isAcceptableOrUnknown(data['index_iri']!, _indexIriMeta));
    } else if (isInserting) {
      context.missing(_indexIriMeta);
    }
    if (data.containsKey('resource_iri')) {
      context.handle(
          _resourceIriMeta,
          resourceIri.isAcceptableOrUnknown(
              data['resource_iri']!, _resourceIriMeta));
    } else if (isInserting) {
      context.missing(_resourceIriMeta);
    }
    if (data.containsKey('resource_type')) {
      context.handle(
          _resourceTypeMeta,
          resourceType.isAcceptableOrUnknown(
              data['resource_type']!, _resourceTypeMeta));
    } else if (isInserting) {
      context.missing(_resourceTypeMeta);
    }
    if (data.containsKey('headers')) {
      context.handle(_headersMeta,
          headers.isAcceptableOrUnknown(data['headers']!, _headersMeta));
    } else if (isInserting) {
      context.missing(_headersMeta);
    }
    if (data.containsKey('clock_hash')) {
      context.handle(_clockHashMeta,
          clockHash.isAcceptableOrUnknown(data['clock_hash']!, _clockHashMeta));
    } else if (isInserting) {
      context.missing(_clockHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {indexIri, resourceIri};
  @override
  IndexEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IndexEntry(
      indexIri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}index_iri'])!,
      resourceIri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_iri'])!,
      resourceType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}resource_type'])!,
      headers: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}headers'])!,
      clockHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}clock_hash'])!,
    );
  }

  @override
  $IndexEntriesTable createAlias(String alias) {
    return $IndexEntriesTable(attachedDatabase, alias);
  }
}

class IndexEntry extends DataClass implements Insertable<IndexEntry> {
  /// Index shard IRI
  final String indexIri;

  /// Indexed resource IRI
  final String resourceIri;

  /// Resource type (for filtering)
  final String resourceType;

  /// Header properties as JSON
  final String headers;

  /// Clock hash for change detection
  final String clockHash;
  const IndexEntry(
      {required this.indexIri,
      required this.resourceIri,
      required this.resourceType,
      required this.headers,
      required this.clockHash});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['index_iri'] = Variable<String>(indexIri);
    map['resource_iri'] = Variable<String>(resourceIri);
    map['resource_type'] = Variable<String>(resourceType);
    map['headers'] = Variable<String>(headers);
    map['clock_hash'] = Variable<String>(clockHash);
    return map;
  }

  IndexEntriesCompanion toCompanion(bool nullToAbsent) {
    return IndexEntriesCompanion(
      indexIri: Value(indexIri),
      resourceIri: Value(resourceIri),
      resourceType: Value(resourceType),
      headers: Value(headers),
      clockHash: Value(clockHash),
    );
  }

  factory IndexEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IndexEntry(
      indexIri: serializer.fromJson<String>(json['indexIri']),
      resourceIri: serializer.fromJson<String>(json['resourceIri']),
      resourceType: serializer.fromJson<String>(json['resourceType']),
      headers: serializer.fromJson<String>(json['headers']),
      clockHash: serializer.fromJson<String>(json['clockHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'indexIri': serializer.toJson<String>(indexIri),
      'resourceIri': serializer.toJson<String>(resourceIri),
      'resourceType': serializer.toJson<String>(resourceType),
      'headers': serializer.toJson<String>(headers),
      'clockHash': serializer.toJson<String>(clockHash),
    };
  }

  IndexEntry copyWith(
          {String? indexIri,
          String? resourceIri,
          String? resourceType,
          String? headers,
          String? clockHash}) =>
      IndexEntry(
        indexIri: indexIri ?? this.indexIri,
        resourceIri: resourceIri ?? this.resourceIri,
        resourceType: resourceType ?? this.resourceType,
        headers: headers ?? this.headers,
        clockHash: clockHash ?? this.clockHash,
      );
  IndexEntry copyWithCompanion(IndexEntriesCompanion data) {
    return IndexEntry(
      indexIri: data.indexIri.present ? data.indexIri.value : this.indexIri,
      resourceIri:
          data.resourceIri.present ? data.resourceIri.value : this.resourceIri,
      resourceType: data.resourceType.present
          ? data.resourceType.value
          : this.resourceType,
      headers: data.headers.present ? data.headers.value : this.headers,
      clockHash: data.clockHash.present ? data.clockHash.value : this.clockHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IndexEntry(')
          ..write('indexIri: $indexIri, ')
          ..write('resourceIri: $resourceIri, ')
          ..write('resourceType: $resourceType, ')
          ..write('headers: $headers, ')
          ..write('clockHash: $clockHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(indexIri, resourceIri, resourceType, headers, clockHash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IndexEntry &&
          other.indexIri == this.indexIri &&
          other.resourceIri == this.resourceIri &&
          other.resourceType == this.resourceType &&
          other.headers == this.headers &&
          other.clockHash == this.clockHash);
}

class IndexEntriesCompanion extends UpdateCompanion<IndexEntry> {
  final Value<String> indexIri;
  final Value<String> resourceIri;
  final Value<String> resourceType;
  final Value<String> headers;
  final Value<String> clockHash;
  final Value<int> rowid;
  const IndexEntriesCompanion({
    this.indexIri = const Value.absent(),
    this.resourceIri = const Value.absent(),
    this.resourceType = const Value.absent(),
    this.headers = const Value.absent(),
    this.clockHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IndexEntriesCompanion.insert({
    required String indexIri,
    required String resourceIri,
    required String resourceType,
    required String headers,
    required String clockHash,
    this.rowid = const Value.absent(),
  })  : indexIri = Value(indexIri),
        resourceIri = Value(resourceIri),
        resourceType = Value(resourceType),
        headers = Value(headers),
        clockHash = Value(clockHash);
  static Insertable<IndexEntry> custom({
    Expression<String>? indexIri,
    Expression<String>? resourceIri,
    Expression<String>? resourceType,
    Expression<String>? headers,
    Expression<String>? clockHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (indexIri != null) 'index_iri': indexIri,
      if (resourceIri != null) 'resource_iri': resourceIri,
      if (resourceType != null) 'resource_type': resourceType,
      if (headers != null) 'headers': headers,
      if (clockHash != null) 'clock_hash': clockHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IndexEntriesCompanion copyWith(
      {Value<String>? indexIri,
      Value<String>? resourceIri,
      Value<String>? resourceType,
      Value<String>? headers,
      Value<String>? clockHash,
      Value<int>? rowid}) {
    return IndexEntriesCompanion(
      indexIri: indexIri ?? this.indexIri,
      resourceIri: resourceIri ?? this.resourceIri,
      resourceType: resourceType ?? this.resourceType,
      headers: headers ?? this.headers,
      clockHash: clockHash ?? this.clockHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (indexIri.present) {
      map['index_iri'] = Variable<String>(indexIri.value);
    }
    if (resourceIri.present) {
      map['resource_iri'] = Variable<String>(resourceIri.value);
    }
    if (resourceType.present) {
      map['resource_type'] = Variable<String>(resourceType.value);
    }
    if (headers.present) {
      map['headers'] = Variable<String>(headers.value);
    }
    if (clockHash.present) {
      map['clock_hash'] = Variable<String>(clockHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IndexEntriesCompanion(')
          ..write('indexIri: $indexIri, ')
          ..write('resourceIri: $resourceIri, ')
          ..write('resourceType: $resourceType, ')
          ..write('headers: $headers, ')
          ..write('clockHash: $clockHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SolidCrdtDatabase extends GeneratedDatabase {
  _$SolidCrdtDatabase(QueryExecutor e) : super(e);
  $SolidCrdtDatabaseManager get managers => $SolidCrdtDatabaseManager(this);
  late final $RdfDocumentsTable rdfDocuments = $RdfDocumentsTable(this);
  late final $RdfTriplesTable rdfTriples = $RdfTriplesTable(this);
  late final $CrdtMetadataTable crdtMetadata = $CrdtMetadataTable(this);
  late final $IndexEntriesTable indexEntries = $IndexEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [rdfDocuments, rdfTriples, crdtMetadata, indexEntries];
}

typedef $$RdfDocumentsTableCreateCompanionBuilder = RdfDocumentsCompanion
    Function({
  required String documentIri,
  required String rdfContent,
  required String clockHash,
  Value<DateTime> lastModified,
  Value<String> syncStatus,
  Value<int> rowid,
});
typedef $$RdfDocumentsTableUpdateCompanionBuilder = RdfDocumentsCompanion
    Function({
  Value<String> documentIri,
  Value<String> rdfContent,
  Value<String> clockHash,
  Value<DateTime> lastModified,
  Value<String> syncStatus,
  Value<int> rowid,
});

final class $$RdfDocumentsTableReferences extends BaseReferences<
    _$SolidCrdtDatabase, $RdfDocumentsTable, RdfDocument> {
  $$RdfDocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RdfTriplesTable, List<RdfTriple>>
      _rdfTriplesRefsTable(_$SolidCrdtDatabase db) =>
          MultiTypedResultKey.fromTable(db.rdfTriples,
              aliasName: $_aliasNameGenerator(
                  db.rdfDocuments.documentIri, db.rdfTriples.documentIri));

  $$RdfTriplesTableProcessedTableManager get rdfTriplesRefs {
    final manager = $$RdfTriplesTableTableManager($_db, $_db.rdfTriples).filter(
        (f) => f.documentIri.documentIri
            .sqlEquals($_itemColumn<String>('document_iri')!));

    final cache = $_typedResult.readTableOrNull(_rdfTriplesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RdfDocumentsTableFilterComposer
    extends Composer<_$SolidCrdtDatabase, $RdfDocumentsTable> {
  $$RdfDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentIri => $composableBuilder(
      column: $table.documentIri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rdfContent => $composableBuilder(
      column: $table.rdfContent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clockHash => $composableBuilder(
      column: $table.clockHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  Expression<bool> rdfTriplesRefs(
      Expression<bool> Function($$RdfTriplesTableFilterComposer f) f) {
    final $$RdfTriplesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.documentIri,
        referencedTable: $db.rdfTriples,
        getReferencedColumn: (t) => t.documentIri,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RdfTriplesTableFilterComposer(
              $db: $db,
              $table: $db.rdfTriples,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RdfDocumentsTableOrderingComposer
    extends Composer<_$SolidCrdtDatabase, $RdfDocumentsTable> {
  $$RdfDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentIri => $composableBuilder(
      column: $table.documentIri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rdfContent => $composableBuilder(
      column: $table.rdfContent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clockHash => $composableBuilder(
      column: $table.clockHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));
}

class $$RdfDocumentsTableAnnotationComposer
    extends Composer<_$SolidCrdtDatabase, $RdfDocumentsTable> {
  $$RdfDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentIri => $composableBuilder(
      column: $table.documentIri, builder: (column) => column);

  GeneratedColumn<String> get rdfContent => $composableBuilder(
      column: $table.rdfContent, builder: (column) => column);

  GeneratedColumn<String> get clockHash =>
      $composableBuilder(column: $table.clockHash, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModified => $composableBuilder(
      column: $table.lastModified, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  Expression<T> rdfTriplesRefs<T extends Object>(
      Expression<T> Function($$RdfTriplesTableAnnotationComposer a) f) {
    final $$RdfTriplesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.documentIri,
        referencedTable: $db.rdfTriples,
        getReferencedColumn: (t) => t.documentIri,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RdfTriplesTableAnnotationComposer(
              $db: $db,
              $table: $db.rdfTriples,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RdfDocumentsTableTableManager extends RootTableManager<
    _$SolidCrdtDatabase,
    $RdfDocumentsTable,
    RdfDocument,
    $$RdfDocumentsTableFilterComposer,
    $$RdfDocumentsTableOrderingComposer,
    $$RdfDocumentsTableAnnotationComposer,
    $$RdfDocumentsTableCreateCompanionBuilder,
    $$RdfDocumentsTableUpdateCompanionBuilder,
    (RdfDocument, $$RdfDocumentsTableReferences),
    RdfDocument,
    PrefetchHooks Function({bool rdfTriplesRefs})> {
  $$RdfDocumentsTableTableManager(
      _$SolidCrdtDatabase db, $RdfDocumentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RdfDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RdfDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RdfDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> documentIri = const Value.absent(),
            Value<String> rdfContent = const Value.absent(),
            Value<String> clockHash = const Value.absent(),
            Value<DateTime> lastModified = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RdfDocumentsCompanion(
            documentIri: documentIri,
            rdfContent: rdfContent,
            clockHash: clockHash,
            lastModified: lastModified,
            syncStatus: syncStatus,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String documentIri,
            required String rdfContent,
            required String clockHash,
            Value<DateTime> lastModified = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RdfDocumentsCompanion.insert(
            documentIri: documentIri,
            rdfContent: rdfContent,
            clockHash: clockHash,
            lastModified: lastModified,
            syncStatus: syncStatus,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RdfDocumentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({rdfTriplesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (rdfTriplesRefs) db.rdfTriples],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (rdfTriplesRefs)
                    await $_getPrefetchedData<RdfDocument, $RdfDocumentsTable,
                            RdfTriple>(
                        currentTable: table,
                        referencedTable: $$RdfDocumentsTableReferences
                            ._rdfTriplesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$RdfDocumentsTableReferences(db, table, p0)
                                .rdfTriplesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.documentIri == item.documentIri),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$RdfDocumentsTableProcessedTableManager = ProcessedTableManager<
    _$SolidCrdtDatabase,
    $RdfDocumentsTable,
    RdfDocument,
    $$RdfDocumentsTableFilterComposer,
    $$RdfDocumentsTableOrderingComposer,
    $$RdfDocumentsTableAnnotationComposer,
    $$RdfDocumentsTableCreateCompanionBuilder,
    $$RdfDocumentsTableUpdateCompanionBuilder,
    (RdfDocument, $$RdfDocumentsTableReferences),
    RdfDocument,
    PrefetchHooks Function({bool rdfTriplesRefs})>;
typedef $$RdfTriplesTableCreateCompanionBuilder = RdfTriplesCompanion Function({
  Value<int> id,
  required String subject,
  required String predicate,
  required String object,
  Value<String?> objectType,
  Value<String?> objectLang,
  required String documentIri,
});
typedef $$RdfTriplesTableUpdateCompanionBuilder = RdfTriplesCompanion Function({
  Value<int> id,
  Value<String> subject,
  Value<String> predicate,
  Value<String> object,
  Value<String?> objectType,
  Value<String?> objectLang,
  Value<String> documentIri,
});

final class $$RdfTriplesTableReferences
    extends BaseReferences<_$SolidCrdtDatabase, $RdfTriplesTable, RdfTriple> {
  $$RdfTriplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RdfDocumentsTable _documentIriTable(_$SolidCrdtDatabase db) =>
      db.rdfDocuments.createAlias($_aliasNameGenerator(
          db.rdfTriples.documentIri, db.rdfDocuments.documentIri));

  $$RdfDocumentsTableProcessedTableManager get documentIri {
    final $_column = $_itemColumn<String>('document_iri')!;

    final manager = $$RdfDocumentsTableTableManager($_db, $_db.rdfDocuments)
        .filter((f) => f.documentIri.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIriTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RdfTriplesTableFilterComposer
    extends Composer<_$SolidCrdtDatabase, $RdfTriplesTable> {
  $$RdfTriplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get predicate => $composableBuilder(
      column: $table.predicate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get object => $composableBuilder(
      column: $table.object, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get objectType => $composableBuilder(
      column: $table.objectType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get objectLang => $composableBuilder(
      column: $table.objectLang, builder: (column) => ColumnFilters(column));

  $$RdfDocumentsTableFilterComposer get documentIri {
    final $$RdfDocumentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.documentIri,
        referencedTable: $db.rdfDocuments,
        getReferencedColumn: (t) => t.documentIri,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RdfDocumentsTableFilterComposer(
              $db: $db,
              $table: $db.rdfDocuments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RdfTriplesTableOrderingComposer
    extends Composer<_$SolidCrdtDatabase, $RdfTriplesTable> {
  $$RdfTriplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get predicate => $composableBuilder(
      column: $table.predicate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get object => $composableBuilder(
      column: $table.object, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get objectType => $composableBuilder(
      column: $table.objectType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get objectLang => $composableBuilder(
      column: $table.objectLang, builder: (column) => ColumnOrderings(column));

  $$RdfDocumentsTableOrderingComposer get documentIri {
    final $$RdfDocumentsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.documentIri,
        referencedTable: $db.rdfDocuments,
        getReferencedColumn: (t) => t.documentIri,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RdfDocumentsTableOrderingComposer(
              $db: $db,
              $table: $db.rdfDocuments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RdfTriplesTableAnnotationComposer
    extends Composer<_$SolidCrdtDatabase, $RdfTriplesTable> {
  $$RdfTriplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get predicate =>
      $composableBuilder(column: $table.predicate, builder: (column) => column);

  GeneratedColumn<String> get object =>
      $composableBuilder(column: $table.object, builder: (column) => column);

  GeneratedColumn<String> get objectType => $composableBuilder(
      column: $table.objectType, builder: (column) => column);

  GeneratedColumn<String> get objectLang => $composableBuilder(
      column: $table.objectLang, builder: (column) => column);

  $$RdfDocumentsTableAnnotationComposer get documentIri {
    final $$RdfDocumentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.documentIri,
        referencedTable: $db.rdfDocuments,
        getReferencedColumn: (t) => t.documentIri,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RdfDocumentsTableAnnotationComposer(
              $db: $db,
              $table: $db.rdfDocuments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RdfTriplesTableTableManager extends RootTableManager<
    _$SolidCrdtDatabase,
    $RdfTriplesTable,
    RdfTriple,
    $$RdfTriplesTableFilterComposer,
    $$RdfTriplesTableOrderingComposer,
    $$RdfTriplesTableAnnotationComposer,
    $$RdfTriplesTableCreateCompanionBuilder,
    $$RdfTriplesTableUpdateCompanionBuilder,
    (RdfTriple, $$RdfTriplesTableReferences),
    RdfTriple,
    PrefetchHooks Function({bool documentIri})> {
  $$RdfTriplesTableTableManager(_$SolidCrdtDatabase db, $RdfTriplesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RdfTriplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RdfTriplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RdfTriplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<String> predicate = const Value.absent(),
            Value<String> object = const Value.absent(),
            Value<String?> objectType = const Value.absent(),
            Value<String?> objectLang = const Value.absent(),
            Value<String> documentIri = const Value.absent(),
          }) =>
              RdfTriplesCompanion(
            id: id,
            subject: subject,
            predicate: predicate,
            object: object,
            objectType: objectType,
            objectLang: objectLang,
            documentIri: documentIri,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String subject,
            required String predicate,
            required String object,
            Value<String?> objectType = const Value.absent(),
            Value<String?> objectLang = const Value.absent(),
            required String documentIri,
          }) =>
              RdfTriplesCompanion.insert(
            id: id,
            subject: subject,
            predicate: predicate,
            object: object,
            objectType: objectType,
            objectLang: objectLang,
            documentIri: documentIri,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RdfTriplesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({documentIri = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                      dynamic>>(state) {
                if (documentIri) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.documentIri,
                    referencedTable:
                        $$RdfTriplesTableReferences._documentIriTable(db),
                    referencedColumn: $$RdfTriplesTableReferences
                        ._documentIriTable(db)
                        .documentIri,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$RdfTriplesTableProcessedTableManager = ProcessedTableManager<
    _$SolidCrdtDatabase,
    $RdfTriplesTable,
    RdfTriple,
    $$RdfTriplesTableFilterComposer,
    $$RdfTriplesTableOrderingComposer,
    $$RdfTriplesTableAnnotationComposer,
    $$RdfTriplesTableCreateCompanionBuilder,
    $$RdfTriplesTableUpdateCompanionBuilder,
    (RdfTriple, $$RdfTriplesTableReferences),
    RdfTriple,
    PrefetchHooks Function({bool documentIri})>;
typedef $$CrdtMetadataTableCreateCompanionBuilder = CrdtMetadataCompanion
    Function({
  required String resourceIri,
  required String installationId,
  required DateTime wallTime,
  required int logicalTime,
  Value<String?> tombstones,
  Value<int> rowid,
});
typedef $$CrdtMetadataTableUpdateCompanionBuilder = CrdtMetadataCompanion
    Function({
  Value<String> resourceIri,
  Value<String> installationId,
  Value<DateTime> wallTime,
  Value<int> logicalTime,
  Value<String?> tombstones,
  Value<int> rowid,
});

class $$CrdtMetadataTableFilterComposer
    extends Composer<_$SolidCrdtDatabase, $CrdtMetadataTable> {
  $$CrdtMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get resourceIri => $composableBuilder(
      column: $table.resourceIri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get installationId => $composableBuilder(
      column: $table.installationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get wallTime => $composableBuilder(
      column: $table.wallTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get logicalTime => $composableBuilder(
      column: $table.logicalTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tombstones => $composableBuilder(
      column: $table.tombstones, builder: (column) => ColumnFilters(column));
}

class $$CrdtMetadataTableOrderingComposer
    extends Composer<_$SolidCrdtDatabase, $CrdtMetadataTable> {
  $$CrdtMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get resourceIri => $composableBuilder(
      column: $table.resourceIri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get installationId => $composableBuilder(
      column: $table.installationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get wallTime => $composableBuilder(
      column: $table.wallTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get logicalTime => $composableBuilder(
      column: $table.logicalTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tombstones => $composableBuilder(
      column: $table.tombstones, builder: (column) => ColumnOrderings(column));
}

class $$CrdtMetadataTableAnnotationComposer
    extends Composer<_$SolidCrdtDatabase, $CrdtMetadataTable> {
  $$CrdtMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get resourceIri => $composableBuilder(
      column: $table.resourceIri, builder: (column) => column);

  GeneratedColumn<String> get installationId => $composableBuilder(
      column: $table.installationId, builder: (column) => column);

  GeneratedColumn<DateTime> get wallTime =>
      $composableBuilder(column: $table.wallTime, builder: (column) => column);

  GeneratedColumn<int> get logicalTime => $composableBuilder(
      column: $table.logicalTime, builder: (column) => column);

  GeneratedColumn<String> get tombstones => $composableBuilder(
      column: $table.tombstones, builder: (column) => column);
}

class $$CrdtMetadataTableTableManager extends RootTableManager<
    _$SolidCrdtDatabase,
    $CrdtMetadataTable,
    CrdtMetadataData,
    $$CrdtMetadataTableFilterComposer,
    $$CrdtMetadataTableOrderingComposer,
    $$CrdtMetadataTableAnnotationComposer,
    $$CrdtMetadataTableCreateCompanionBuilder,
    $$CrdtMetadataTableUpdateCompanionBuilder,
    (
      CrdtMetadataData,
      BaseReferences<_$SolidCrdtDatabase, $CrdtMetadataTable, CrdtMetadataData>
    ),
    CrdtMetadataData,
    PrefetchHooks Function()> {
  $$CrdtMetadataTableTableManager(
      _$SolidCrdtDatabase db, $CrdtMetadataTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrdtMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CrdtMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CrdtMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> resourceIri = const Value.absent(),
            Value<String> installationId = const Value.absent(),
            Value<DateTime> wallTime = const Value.absent(),
            Value<int> logicalTime = const Value.absent(),
            Value<String?> tombstones = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CrdtMetadataCompanion(
            resourceIri: resourceIri,
            installationId: installationId,
            wallTime: wallTime,
            logicalTime: logicalTime,
            tombstones: tombstones,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String resourceIri,
            required String installationId,
            required DateTime wallTime,
            required int logicalTime,
            Value<String?> tombstones = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CrdtMetadataCompanion.insert(
            resourceIri: resourceIri,
            installationId: installationId,
            wallTime: wallTime,
            logicalTime: logicalTime,
            tombstones: tombstones,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CrdtMetadataTableProcessedTableManager = ProcessedTableManager<
    _$SolidCrdtDatabase,
    $CrdtMetadataTable,
    CrdtMetadataData,
    $$CrdtMetadataTableFilterComposer,
    $$CrdtMetadataTableOrderingComposer,
    $$CrdtMetadataTableAnnotationComposer,
    $$CrdtMetadataTableCreateCompanionBuilder,
    $$CrdtMetadataTableUpdateCompanionBuilder,
    (
      CrdtMetadataData,
      BaseReferences<_$SolidCrdtDatabase, $CrdtMetadataTable, CrdtMetadataData>
    ),
    CrdtMetadataData,
    PrefetchHooks Function()>;
typedef $$IndexEntriesTableCreateCompanionBuilder = IndexEntriesCompanion
    Function({
  required String indexIri,
  required String resourceIri,
  required String resourceType,
  required String headers,
  required String clockHash,
  Value<int> rowid,
});
typedef $$IndexEntriesTableUpdateCompanionBuilder = IndexEntriesCompanion
    Function({
  Value<String> indexIri,
  Value<String> resourceIri,
  Value<String> resourceType,
  Value<String> headers,
  Value<String> clockHash,
  Value<int> rowid,
});

class $$IndexEntriesTableFilterComposer
    extends Composer<_$SolidCrdtDatabase, $IndexEntriesTable> {
  $$IndexEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get indexIri => $composableBuilder(
      column: $table.indexIri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resourceIri => $composableBuilder(
      column: $table.resourceIri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resourceType => $composableBuilder(
      column: $table.resourceType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get headers => $composableBuilder(
      column: $table.headers, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clockHash => $composableBuilder(
      column: $table.clockHash, builder: (column) => ColumnFilters(column));
}

class $$IndexEntriesTableOrderingComposer
    extends Composer<_$SolidCrdtDatabase, $IndexEntriesTable> {
  $$IndexEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get indexIri => $composableBuilder(
      column: $table.indexIri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resourceIri => $composableBuilder(
      column: $table.resourceIri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resourceType => $composableBuilder(
      column: $table.resourceType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get headers => $composableBuilder(
      column: $table.headers, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clockHash => $composableBuilder(
      column: $table.clockHash, builder: (column) => ColumnOrderings(column));
}

class $$IndexEntriesTableAnnotationComposer
    extends Composer<_$SolidCrdtDatabase, $IndexEntriesTable> {
  $$IndexEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get indexIri =>
      $composableBuilder(column: $table.indexIri, builder: (column) => column);

  GeneratedColumn<String> get resourceIri => $composableBuilder(
      column: $table.resourceIri, builder: (column) => column);

  GeneratedColumn<String> get resourceType => $composableBuilder(
      column: $table.resourceType, builder: (column) => column);

  GeneratedColumn<String> get headers =>
      $composableBuilder(column: $table.headers, builder: (column) => column);

  GeneratedColumn<String> get clockHash =>
      $composableBuilder(column: $table.clockHash, builder: (column) => column);
}

class $$IndexEntriesTableTableManager extends RootTableManager<
    _$SolidCrdtDatabase,
    $IndexEntriesTable,
    IndexEntry,
    $$IndexEntriesTableFilterComposer,
    $$IndexEntriesTableOrderingComposer,
    $$IndexEntriesTableAnnotationComposer,
    $$IndexEntriesTableCreateCompanionBuilder,
    $$IndexEntriesTableUpdateCompanionBuilder,
    (
      IndexEntry,
      BaseReferences<_$SolidCrdtDatabase, $IndexEntriesTable, IndexEntry>
    ),
    IndexEntry,
    PrefetchHooks Function()> {
  $$IndexEntriesTableTableManager(
      _$SolidCrdtDatabase db, $IndexEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IndexEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IndexEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IndexEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> indexIri = const Value.absent(),
            Value<String> resourceIri = const Value.absent(),
            Value<String> resourceType = const Value.absent(),
            Value<String> headers = const Value.absent(),
            Value<String> clockHash = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              IndexEntriesCompanion(
            indexIri: indexIri,
            resourceIri: resourceIri,
            resourceType: resourceType,
            headers: headers,
            clockHash: clockHash,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String indexIri,
            required String resourceIri,
            required String resourceType,
            required String headers,
            required String clockHash,
            Value<int> rowid = const Value.absent(),
          }) =>
              IndexEntriesCompanion.insert(
            indexIri: indexIri,
            resourceIri: resourceIri,
            resourceType: resourceType,
            headers: headers,
            clockHash: clockHash,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$IndexEntriesTableProcessedTableManager = ProcessedTableManager<
    _$SolidCrdtDatabase,
    $IndexEntriesTable,
    IndexEntry,
    $$IndexEntriesTableFilterComposer,
    $$IndexEntriesTableOrderingComposer,
    $$IndexEntriesTableAnnotationComposer,
    $$IndexEntriesTableCreateCompanionBuilder,
    $$IndexEntriesTableUpdateCompanionBuilder,
    (
      IndexEntry,
      BaseReferences<_$SolidCrdtDatabase, $IndexEntriesTable, IndexEntry>
    ),
    IndexEntry,
    PrefetchHooks Function()>;

class $SolidCrdtDatabaseManager {
  final _$SolidCrdtDatabase _db;
  $SolidCrdtDatabaseManager(this._db);
  $$RdfDocumentsTableTableManager get rdfDocuments =>
      $$RdfDocumentsTableTableManager(_db, _db.rdfDocuments);
  $$RdfTriplesTableTableManager get rdfTriples =>
      $$RdfTriplesTableTableManager(_db, _db.rdfTriples);
  $$CrdtMetadataTableTableManager get crdtMetadata =>
      $$CrdtMetadataTableTableManager(_db, _db.crdtMetadata);
  $$IndexEntriesTableTableManager get indexEntries =>
      $$IndexEntriesTableTableManager(_db, _db.indexEntries);
}
