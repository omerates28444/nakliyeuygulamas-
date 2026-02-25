import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status; // open/matched/delivered_pending/done/rejected/countered...
  final String? overrideText;

  const StatusChip({super.key, required this.status, this.overrideText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color c;
    IconData ic;
    String t;

    switch (status) {
      case "open":
        c = Colors.green;
        ic = Icons.circle;
        t = "Açık";
        break;
      case "matched":
        c = Colors.blue;
        ic = Icons.handshake_outlined;
        t = "Eşleşti";
        break;
      case "delivered_pending":
        c = Colors.orange;
        ic = Icons.hourglass_bottom;
        t = "Onay bekliyor";
        break;
      case "done":
        c = Colors.green;
        ic = Icons.check_circle_outline;
        t = "Tamamlandı";
        break;
      case "rejected":
        c = Colors.red;
        ic = Icons.cancel_outlined;
        t = "Reddedildi";
        break;
      case "countered":
        c = Colors.orange;
        ic = Icons.forum_outlined;
        t = "Karşı teklif";
        break;
      default:
        c = cs.onSurfaceVariant;
        ic = Icons.info_outline;
        t = status;
    }

    final label = overrideText ?? t;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c),
        color: c.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 16, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    );
  }
}