import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/deal.dart';
import 'deal_detail_screen.dart';

/// Full list of every currently live Deal across all businesses — reached
/// from the Home tab's "Today's Deal" carousel via "See all". Distinct
/// from the Surprise Bag surplus listings shown in a separate carousel.
class AllDealsScreen extends StatelessWidget {
  const AllDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Deal")),
      body: StreamBuilder<List<Deal>>(
        stream: databaseService.streamActiveDeals(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final deals = snapshot.data!;
          if (deals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No deals right now — check back soon!',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: deals.length,
            itemBuilder: (context, i) {
              final deal = deals[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: deal.imageUrl != null
                        ? Image.network(deal.imageUrl!, width: 56, height: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                  title: Text(deal.menuItemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${deal.businessName} \u2022 ${deal.discountPercent.round()}% off',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Rs. ${deal.discountedPrice.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      Text('Rs. ${deal.originalPrice.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: Colors.grey.shade500)),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DealDetailScreen(deal: deal)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56, height: 56,
      color: Colors.green.shade50,
      child: Icon(Icons.local_offer_outlined, color: Colors.green.shade300),
    );
  }
}
