import 'dart:convert';
import 'package:finma_adview/src/models/constants.dart';
import 'package:http/http.dart' as http;
import '../models/ad_item.dart';

class AdApiService {
  // Queries your backend API configuration registry endpoint
  static Future<List<AdItem>> fetchAdList(String clientId) async {
    try {
      print("hellow api " + clientId);
      final response = await http
          .get(Uri.parse(Constants.kApiUrl + "/" + clientId))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> outerJson = jsonDecode(response.body);

        // Check if the response status is "success" and data map exists
        if (outerJson['status'] == 'success' && outerJson['data'] != null) {
          final Map<String, dynamic> dataPayload = outerJson['data'];
          final List<dynamic> adsList = dataPayload['ads'] ?? [];

          return adsList.map((json) => AdItem.fromJson(json)).toList();
        }
        print(
          "⚠️ Ad server responded with unexpected status logic mapping: ${outerJson['message']}",
        );
        return [];
      } else {
        print(
          "⚠️ Failed loading ads from backend. Status: ${response.statusCode}",
        );
        return [];
      }
    } catch (e) {
      print("❌ Error hitting ad server endpoint: $e");
      return []; // Return empty array so local caching handles fallback cleanly
    }
  }

  /// Dispatches a collected list matrix array of analytics logs to the server in a single call.
  static Future<bool> logBatchEventsToServer(
    List<Map<String, dynamic>> eventsList,
  ) async {
    if (eventsList.isEmpty) return true;

    final Uri targetUrl = Uri.parse(Constants.kLogEventUrl);
    print("Calling logBatchEventsToServer");
    try {
      final response = await http
          .post(
            targetUrl,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"events": eventsList}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print("❌ Failed syncing batch analytics payload to server: $e");
      return false; // Returns false so cache retains items if network drops
    }
  }
}
