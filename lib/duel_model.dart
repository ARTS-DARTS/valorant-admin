import 'package:cloud_firestore/cloud_firestore.dart';

class Duel {
  final String id;
  final String lineup1Id;
  final String lineup2Id;
  final String mapName;
  final int votes1;
  final int votes2;
  final DateTime endsAt;
  final String status;

  const Duel({
    required this.id,
    required this.lineup1Id,
    required this.lineup2Id,
    required this.mapName,
    required this.votes1,
    required this.votes2,
    required this.endsAt,
    required this.status,
  });

  factory Duel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Duel(
      id: doc.id,
      lineup1Id: d['lineup1Id'] as String? ?? '',
      lineup2Id: d['lineup2Id'] as String? ?? '',
      mapName: d['mapName'] as String? ?? '',
      votes1: (d['votes1'] as num?)?.toInt() ?? 0,
      votes2: (d['votes2'] as num?)?.toInt() ?? 0,
      endsAt: (d['endsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] as String? ?? 'active',
    );
  }

  int get totalVotes => votes1 + votes2;
  double get percent1 => totalVotes == 0 ? 50.0 : votes1 / totalVotes * 100;
  double get percent2 => totalVotes == 0 ? 50.0 : votes2 / totalVotes * 100;
  bool get isActive => status == 'active';

  Duration get timeLeft {
    final diff = endsAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get timeLeftLabel {
    final d = timeLeft;
    if (d == Duration.zero) return 'Завершена';
    if (d.inDays > 0) return '${d.inDays}д ${d.inHours % 24}ч';
    if (d.inHours > 0) return '${d.inHours}ч ${d.inMinutes % 60}мин';
    return '${d.inMinutes}мин';
  }
}
