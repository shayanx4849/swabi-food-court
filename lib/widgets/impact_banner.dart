import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Shows the app-wide environmental impact — total meals rescued and
/// estimated CO2 avoided — sourced from DatabaseService.streamGlobalImpact().
/// This is what makes the "reduce food waste" angle visible/tangible to
/// the user, not just a background statistic.
class ImpactBanner extends StatelessWidget {
  const ImpactBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();

    return StreamBuilder<Map<String, num>>(
      stream: databaseService.streamGlobalImpact(),
      builder: (context, snapshot) {
        final meals = snapshot.data?['mealsRescued'] ?? 0;
        final co2 = snapshot.data?['kgCo2Saved'] ?? 0;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.green.shade400],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.eco, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$meals meal${meals == 1 ? '' : 's'} rescued so far',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '≈ ${co2.toStringAsFixed(1)} kg CO₂ avoided together',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
