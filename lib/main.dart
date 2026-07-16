// ==========================================
// 3. TESTING SUITE / SAMPLE APP VIEW
// ==========================================


import 'package:finma_adview/src/models/ad_item.dart';
import 'package:finma_adview/src/widgets/banner_ad_view.dart';
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
            clientId: "client_456",
          ),
        ],
      ),
    ),
  );
}
}
