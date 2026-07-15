import 'dart:io';
import 'package:finma_adview/src/models/ad_item.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class AdCacheManager {
  static Future<Map<String, String>> downloadAndCacheAds(List<AdItem> items) async {
    Map<String, String> localPaths = {};
    
    // CHANGED: Use getApplicationDocumentsDirectory so the OS never deletes your cached ads offline
    final directory = await getApplicationDocumentsDirectory();
    final dio = Dio();
    
    // Set a aggressive connection timeout so it fails fast when offline instead of hanging
    dio.options.connectTimeout = const Duration(seconds: 3);
    dio.options.receiveTimeout = const Duration(seconds: 3);

    for (var item in items) {
      print("🔄 Processing ad item: ${item.id} with asset URL: ${item.assetUrl}");
      if (item.assetUrl.isEmpty) continue;
      
      try {
        final uri = Uri.parse(item.assetUrl);
        final extension = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('.').last : 'png';
        final savePath = '${directory.path}/ad_rotation/${item.id}.$extension';
        
        final file = File(savePath);
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }

        // If a zero-byte file managed to slip through, clear it out
        if (await file.exists() && await file.length() == 0) {
          await file.delete();
        }

        // If file does NOT exist, attempt a fresh download
        if (!await file.exists()) {
          try {
            print("🌐 Downloading fresh asset for ad: ${item.id}");
            await dio.download(
              item.assetUrl, 
              savePath,
              options: Options(responseType: ResponseType.bytes),
            );
          } catch (downloadError) {
            // Catch network disconnect exceptions right here so the loop doesn't break
            print("📡 Network unavailable or download failed for ${item.id}, checking local fallback...");
          }
        } else {
          print("💾 Cache Hit! Loading ${item.id} directly from persistent local storage.");
        }
        
        // CRITICAL FIX: Verify the file exists locally now (either pre-existing or just downloaded)
        if (await file.exists() && await file.length() > 0) {
          localPaths[item.id] = savePath;
        }
      } catch (e) {
        print("❌ General processing failure for asset ${item.id}: $e");
      }
    }
    return localPaths;
  }
}