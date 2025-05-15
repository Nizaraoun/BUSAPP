import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapLegendDialog extends StatelessWidget {
  const MapLegendDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Légende de la carte'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendItem(
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              'Votre position',
              context,
            ),
            _buildLegendItem(
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              'Arrêt de bus',
              context,
            ),
            _buildLegendItem(
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              'Bus',
              context,
            ),
            _buildLegendItem(
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
              'Chauffeur de bus (temps réel)',
              context,
            ),
            _buildLegendItem(
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
              'Résultat de recherche',
              context,
            ),
            const Divider(),
            const Text(
              'Lignes et zones:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 4,
                  child: ColoredBox(color: Colors.blue),
                ),
                SizedBox(width: 8),
                Text('Itinéraire de bus'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Précision GPS'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.7),
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Rayon de recherche des stations'),
              ],
            ),
            const Divider(),
            const Text(
              'Suivi du chauffeur:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.track_changes,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                      'Auto-focus activé: Suivi automatique de la position du chauffeur'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E2A47),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.track_changes_outlined,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text('Auto-focus désactivé: Pas de suivi automatique'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Fermer'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  // Build a legend item
  Widget _buildLegendItem(
      BitmapDescriptor icon, String label, BuildContext context) {
    // Since we can't directly show BitmapDescriptor, we use a colored circle instead
    Color markerColor = Colors.red;

    if (icon ==
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)) {
      markerColor = Colors.blue;
    } else if (icon ==
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)) {
      markerColor = Colors.green;
    } else if (icon ==
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet)) {
      markerColor = Colors.purple;
    } else if (icon ==
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow)) {
      markerColor = Colors.amber;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(Icons.location_on, color: markerColor, size: 24),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

void showMapLegend(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) => const MapLegendDialog(),
  );
}
