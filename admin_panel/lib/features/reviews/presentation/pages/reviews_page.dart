import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/status_badge.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('reviews').limit(50).get();
      setState(() {
        _reviews = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: DataTableView(
        title: 'Review Moderation Panel',
        isLoading: _isLoading,
        columns: const [
          DataColumnItem(label: 'CUSTOMER'),
          DataColumnItem(label: 'PROVIDER'),
          DataColumnItem(label: 'RATING'),
          DataColumnItem(label: 'REVIEW COMMENT'),
          DataColumnItem(label: 'STATUS'),
        ],
        rows: _reviews.map((r) {
          return DataRow(
            cells: [
              DataCell(Text(r['customerName'] ?? 'N/A')),
              DataCell(Text(r['providerName'] ?? 'N/A')),
              DataCell(Text('⭐ ${r['rating'] ?? 5}')),
              DataCell(Text(r['comment'] ?? 'No comment')),
              DataCell(StatusBadge.fromStatus(r['status'] ?? 'active')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
