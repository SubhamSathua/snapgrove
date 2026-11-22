class MoveRecord {
  final String originalSource;
  final String exactDestination;
  final String targetFolder;
  final DateTime timestamp;

  const MoveRecord({
    required this.originalSource,
    required this.exactDestination,
    required this.targetFolder,
    required this.timestamp,
  });
}

class MoveResult {
  final List<MoveRecord> succeededRecords;
  final List<String> failedSources;

  const MoveResult({
    required this.succeededRecords,
    this.failedSources = const [],
  });

  bool get isSuccess => failedSources.isEmpty && succeededRecords.isNotEmpty;
  bool get isPartial => succeededRecords.isNotEmpty && failedSources.isNotEmpty;
  bool get isTotalFailure => succeededRecords.isEmpty;
  int get totalMoved => succeededRecords.length;
  int get totalFailed => failedSources.length;
  List<String> get movedSources => succeededRecords.map((r) => r.originalSource).toList();
  List<String> get movedDestinations => succeededRecords.map((r) => r.exactDestination).toList();
}
