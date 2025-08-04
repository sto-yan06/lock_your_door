class LockStatus{
  final bool isLocked;
  final String? photoPath;
  final DateTime? timestamp;

  LockStatus({
    required this.isLocked,
    this.photoPath,
    this.timestamp,
  });
}