// ==========================================
// 3. TESTING SUITE / SAMPLE APP VIEW
// ==========================================


import 'package:ayk_adview/src/models/ad_item.dart';
import 'package:ayk_adview/src/widgets/banner_ad_view.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      home: AdTesterDashboard(),
      debugShowCheckedModeBanner: false,
    ),
  );
}
class AdTesterDashboard extends StatelessWidget {
  AdTesterDashboard({Key? key}) : super(key: key);
// Mocking array maps received directly via API pipeline queries
final List<AdItem> serverAdQueue = [
  AdItem(
    id: "promo_static_1",
    assetUrl: "https://cobber-1122.web.app/ads/banner.png",
    actionUrl: "https://google.com",
    durationSeconds: 4, // Brief exposure window configuration
  ),
  AdItem(
    id: "promo_gif_2",
    assetUrl: "https://cobber-1122.web.app/ads/banner.gif",
    actionUrl: "https://flutter.dev",
    durationSeconds: 10, // Longer runtime window for animated artwork tracking
  ),
];

// Displaying the component structure within your applications layout tree
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text("Custom Delay Ad Rotator")),
    body: Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          BannerAdView(
            clientId: "client_123",
          ),
        ],
      ),
    ),
  );
}
}
