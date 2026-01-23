import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/features/scanner/camera.dart';

class ScannedLead extends StatefulWidget {
  const ScannedLead({super.key});

  @override
  State<ScannedLead> createState() => _ScannedLeadState();
}

class _ScannedLeadState extends State<ScannedLead> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 4,
      color: colorScheme.primary,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.roundness),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('3',
                  style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {},
                child: Text('View All',
                    style: TextStyle(color: colorScheme.onPrimary)),
              ),
            ]),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scans/Leads',
                    style: TextStyle(
                      color: colorScheme.onPrimary.withOpacity(0.8),
                    )),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const CameraScreen()),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConfig.roundness),
                      ),
                    ),
                    child: Text('Scan',
                        style: TextStyle(color: colorScheme.onPrimary)),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
