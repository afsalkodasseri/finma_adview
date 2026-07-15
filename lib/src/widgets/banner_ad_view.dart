import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:finma_adview/src/models/ad_item.dart';
import 'package:finma_adview/src/models/constants.dart';
import 'package:finma_adview/src/services/ad_cache_manager.dart';
import 'package:finma_adview/src/services/ad_api_service.dart'; // Import your new API service layer
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BannerAdView extends StatefulWidget {
  final String
  clientId; // CHANGED: Pass the endpoint URL string instead of a static list
  final double aspectRatio; // Default aspect ratio for banner ads
  final Decoration? decoration;

  // ADD THESE ANALYTICS HOOKS
  final Function(AdItem ad)?
  onAdImpression; // Triggered when an ad becomes visible
  final Function(AdItem ad)? onAdClick;

  const BannerAdView({
    Key? key,
    required this.clientId, // Enforce configuration injection from target app
    this.aspectRatio = 373 / 117,
    this.decoration = null,
    this.onAdImpression,
    this.onAdClick,
  }) : super(key: key);

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView>
    with WidgetsBindingObserver {
  List<AdItem> _adList =
      []; // CHANGED: Managed internally inside the local state array matrix now
  int _currentIndex = 0;
  Timer? _rotationTimer;
  Map<String, String> _localCachePaths = {};
  bool _isLoading = true;
  bool _imageFailed = false;
  bool _htmlFailed = false;
  WebViewController? _fallbackWebViewController;

  // Local collection storage container matrix queue
  List<Map<String, dynamic>> _analyticsQueue = [];
  Timer? _batchSyncTimer;

  static const String _kStorageQueueKey = 'ayk_adview_analytics_queue';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 1. First, recover any legacy events stored on disk before app was killed
    _loadQueueFromStorage().then((_) {
      _initializeAdStream();
      // 💡 FLUSH IMMEDIATELY ON LAUNCH IF OLD DATA EXISTS
      if (_analyticsQueue.isNotEmpty) {
        _flushAnalyticsQueue();
      }
      _startBatchSyncTimer();
    });
  }

  @override
  void dispose() {
    // 3. Unregister the observer and cancel the active timer securely
    WidgetsBinding.instance.removeObserver(this);
    _rotationTimer?.cancel(); // Clear threading timers securely[cite: 3]
    _batchSyncTimer?.cancel();
    super.dispose();
  }

  /// Reads cached logs from disk storage space during library initialization
  Future<void> _loadQueueFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? serializedData = prefs.getString(_kStorageQueueKey);

      if (serializedData != null && serializedData.isNotEmpty) {
        final List<dynamic> decodedRawList = jsonDecode(serializedData);
        setState(() {
          _analyticsQueue = decodedRawList
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
        debugPrint(
          "💾 [Storage Cache] Successfully loaded ${_analyticsQueue.length} historical pending events from disk storage.",
        );
      }
    } catch (e) {
      debugPrint(
        "❌ Failed reading analytics tracking logs from local device memory storage: $e",
      );
    }
  }

  /// Commits the active state queue matrix collection directly onto physical storage blocks
  Future<void> _saveQueueToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String serializedData = jsonEncode(_analyticsQueue);
      await prefs.setString(_kStorageQueueKey, serializedData);
    } catch (e) {
      debugPrint(
        "❌ Failed writing analytic updates down onto application disk cache partitions: $e",
      );
    }
  }

  void _startBatchSyncTimer() {
    _batchSyncTimer?.cancel();
    _batchSyncTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _flushAnalyticsQueue();
    });
  }

  Future<void> _flushAnalyticsQueue() async {
    if (_analyticsQueue.isEmpty) return;

    // Create a working thread copy array isolate target payload to transmit safely
    final List<Map<String, dynamic>> batchToSend = List.from(_analyticsQueue);

    // Clear the active tracking list state layout memory map and update disk instantly
    setState(() {
      _analyticsQueue.clear();
    });
    await _saveQueueToStorage();

    debugPrint(
      "🔄 [Sync Engine] Attempting to sync ${batchToSend.length} queued ad events to server backend...",
    );

    final success = await AdApiService.logBatchEventsToServer(batchToSend);

    if (success) {
      debugPrint(
        "✅ [Sync Engine] Batch transaction accepted completely by cloud API.",
      );
    } else {
      debugPrint(
        "⚠️ [Sync Engine] Network target offline. Rolling back metrics array collection cache to persistent memory storage pools.",
      );
      if (mounted) {
        setState(() {
          _analyticsQueue.addAll(batchToSend);
        });
        await _saveQueueToStorage(); // Write rolled back array metrics values safely back down onto disk
      }
    }
  }

  // --- REFACTORED MUTATOR TRACKING INTERCEPTORS ---

  void _addItemToQueue(Map<String, dynamic> eventItem) {
    setState(() {
      _analyticsQueue.add(eventItem);
    });
    // Immediately write down to storage whenever an event fires so data survives if app is suddenly terminated
    _saveQueueToStorage();
  }

  // 4. Intercept the Android/iOS OS App State Transitions
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // User minimized app or locked the screen -> Freeze the rotation loop instantly
      _rotationTimer?.cancel();
      _trackViewLifeCycle(false); // Track visibility state change
      debugPrint(
        "⏸️ App hidden/locked. Ad rotation paused to save impression count integrity.",
      );
    } else if (state == AppLifecycleState.resumed) {
      // User returned to the app -> Track the current banner again and resume rotation loop
      debugPrint("▶️ App resumed. Restarting rotation timer.");
      _trackViewLifeCycle(true); // Track visibility state change
      _trackCurrentImpression();
      _scheduleNextAdRotation();
    }
  }

  Future<void> _initializeAdStream() async {
    // 1. Fetch the raw layout configurations directly inside the library logic layer
    final fetchedAds = await AdApiService.fetchAdList(widget.clientId);
    print(
      fetchedAds.length.toString() +
          " ads fetched from API endpoint: ${widget.clientId}",
    );

    if (fetchedAds.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    _adList = fetchedAds;

    // 2. Prefetch images and GIFs down to persistent storage sandboxing[cite: 3]
    final paths = await AdCacheManager.downloadAndCacheAds(_adList);

    if (mounted) {
      setState(() {
        _localCachePaths = paths; // Register the local files[cite: 3]
        _isLoading = false; // Flag ready state[cite: 3]
      });
      // TRACK FIRST AD IMPRESSION
      _trackCurrentImpression();
      // 3. Fire up the dynamic duration loop scheduler[cite: 3]
      _scheduleNextAdRotation();
    }
  }

  void _scheduleNextAdRotation() {
    _rotationTimer?.cancel(); // Reset loop markers[cite: 3]
    if (_adList.isEmpty) return;

    final currentAd = _adList[_currentIndex];

    // Create dynamically adjusted timer duration limits per item config criteria[cite: 3]
    _rotationTimer = Timer(Duration(seconds: currentAd.durationSeconds), () {
      if (mounted) {
        setState(() {
          // Increment or wrap around loop boundaries safely[cite: 3]
          _currentIndex = (_currentIndex + 1) % _adList.length;
          // RESET STATE FLAGS ON EACH ROTATION RUN
          _imageFailed = false;
          _htmlFailed = false;
          _fallbackWebViewController = null;
        });

        // TRACK NEXT AD IMPRESSION ONCE INDEX MUTATES
        _trackCurrentImpression();

        // Recursively trigger next timer window using new ad index payload metadata[cite: 3]
        _scheduleNextAdRotation();
      }
    });
  }

  // Helper method to execute the callback safely
  void _trackCurrentImpression() {
    if (_adList.isNotEmpty) {
      final activeAd = _adList[_currentIndex];

      // 1. Invoke local widget level parameter callback hooks
      if (widget.onAdImpression != null) {
        widget.onAdImpression!(activeAd);
      }

      _addItemToQueue({
        "clientId": widget.clientId,
        "eventType": 'impression',
        "adId": activeAd.id,
        "timestamp": DateTime.now().toIso8601String(),
        "extraInfo": "",
      });
    }
  }

  // Helper method to execute the callback safely
  void _trackViewLifeCycle(bool isVisible) {
    if (_adList.isNotEmpty) {
      final activeAd = _adList[_currentIndex];
      final eventLabel = isVisible ? 'resume' : 'pause';

      print("👁️ Ad ${activeAd.id} visibility changed: $isVisible");

      _addItemToQueue({
        "clientId": widget.clientId,
        "eventType": eventLabel,
        "adId": activeAd.id,
        "timestamp": DateTime.now().toIso8601String(),
        "extraInfo": "",
      });
    }
  }

  // Helper method to execute the callback safely
  void _trackClickAction() {
    if (_adList.isNotEmpty) {
      final activeAd = _adList[_currentIndex];

      // 1. Invoke local widget level parameter callback hooks[cite: 5]
      if (widget.onAdClick != null) {
        widget.onAdClick!(activeAd);
      }

      // 2. Fire and forget tracking log directly to server[cite: 5]
      _addItemToQueue({
        "clientId": widget.clientId,
        "eventType": 'click',
        "adId": activeAd.id,
        "timestamp": DateTime.now().toIso8601String(),
        "extraInfo": "Targeting: ${activeAd.actionUrl}",
      });
    }
  }

  void _trackImageLoadFailure(AdItem ad, String errorMessage) {
    debugPrint("⚠️ Image load failed tracking registered for: ${ad.id}");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _addItemToQueue({
          "clientId": widget.clientId,
          "eventType": 'image_load_failed',
          "adId": ad.id,
          "timestamp": DateTime.now().toIso8601String(),
          "extraInfo": "Error: $errorMessage | Fallback to HTML triggered.",
        });
      }
    });
  }

  void _trackHtmlLoadFailure(AdItem ad, String errorMessage) {
    debugPrint("⚠️ HTML load failed tracking registered for: ${ad.id}");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _addItemToQueue({
          "clientId": widget.clientId,
          "eventType": 'html_load_failed',
          "adId": ad.id,
          "timestamp": DateTime.now().toIso8601String(),
          "extraInfo":
              "Error: $errorMessage | Fallback to placeholder triggered.",
        });
      }
    });
  }

  void _handleAdClick(String destinationUrl) async {
    if (destinationUrl.isNotEmpty) {
      final Uri url = Uri.parse(destinationUrl);
      if (await canLaunchUrl(url)) {
        _trackClickAction(); // Trigger the click callback before launching
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        ); // System browser jump[cite: 3]
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. COLLAPSE EMPTY SPACE COMPLETELY WHILE DOWNLOADING[cite: 3]
    // Replaced the aspect-ratio placeholder box and spinner with an invisible widget bounds[cite: 3]
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    // 2. EXTRA CONFLATION CHECK[cite: 3]
    // Collapses layout frame space if list payload arguments are empty[cite: 3]
    // OR if zero local assets were populated during initialization[cite: 3]
    if (_adList.isEmpty || _localCachePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeAd = _adList[_currentIndex];
    final localPath = _localCachePaths[activeAd.id];
    final hasValidLocalFile = localPath != null && File(localPath).existsSync();
    Clip clipBehavior = widget.decoration != null ? Clip.antiAlias : Clip.none;

    return GestureDetector(
      onTap: () => _handleAdClick(activeAd.actionUrl),
      child: AspectRatio(
        // Enforces the aspect ratio dynamically based on screen width bounds[cite: 3]
        aspectRatio: widget.aspectRatio,
        child: Container(
          clipBehavior: clipBehavior,
          decoration: widget.decoration,
          // Ensures the container takes available room up to parent layout rules[cite: 3]
          width: double.infinity,
          height: double.infinity,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: hasValidLocalFile
                ? Image.file(
                    File(localPath),
                    key: ValueKey<String>("file_${activeAd.id}"),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint(
                        "⚠️ Local decode failed for ${activeAd.id}. Falling back to URL.[cite: 3]",
                      );
                      return _buildNetworkImage(activeAd);
                    },
                  )
                : _buildNetworkImage(activeAd),
          ),
        ),
      ),
    );
  }

  // Separate helper widget to stream image from web source safely[cite: 3]
  Widget _buildNetworkImage(AdItem ad) {
    // Tier 3: If both Image and HTML fallbacks fail, display the asset placeholder image
    if (_htmlFailed) {
      return Image.asset(
        'assets/images/placeholder_ad.png', // Ensure this exists in your library's pubspec.yaml
        key: ValueKey<String>("asset_fallback_${ad.id}"),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          // Absolute fallback icon if the asset path is misconfigured
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          );
        },
      );
    }

    // Tier 2: If the network image fails, attempt to render the HTML structure instead
    if (_imageFailed) {
      // Lazy initialize the web view instance engine context safely on demand
      if (_fallbackWebViewController == null) {
        _fallbackWebViewController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onWebResourceError: (WebResourceError error) {
                debugPrint(
                  "❌ Embedded HTML page loader failed: ${error.description}",
                );
                _trackHtmlLoadFailure(
                  ad,
                  "HTML page loader failed: ${error.description}",
                );
                if (mounted) {
                  setState(() {
                    _htmlFailed = true;
                  });
                }
              },
              onNavigationRequest: (NavigationRequest request) {
                // 1. Intercept all internal hyper-links or form submission anchors clicked inside the page
                // and redirect the main app layout out to the defined actionUrl instead.
                _handleAdClick(ad.actionUrl);
                return NavigationDecision
                    .prevent; // Block navigation inside the small webview window
              },
            ),
          )
          ..addJavaScriptChannel(
            'AdViewChannel',
            onMessageReceived: (JavaScriptMessage message) {
              if (message.message == 'adClicked') {
                _handleAdClick(ad.actionUrl);
              }
            },
          )
          // Load the pure web address target.
          // (Assuming ad.actionUrl or a web endpoint hosted on your firebase site)
          ..loadRequest(
            Uri.parse(Constants.kErrorPageUrl),
            method: LoadRequestMethod.get,
            // Add HTTP headers to prevent server-side and browser-side caching
            headers: {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
          ); // Fallback HTML page hosted on Firebase
      }

      return SizedBox(
        key: ValueKey<String>("html_url_fallback_${ad.id}"),
        width: double.infinity,
        height: double.infinity,
        // Wrap with IgnorePointer so clicks fall through to the parent GestureDetector
        child: Stack(
          children: [
            // 1. The underlying webview content frame (forced to ignore pointers)
            IgnorePointer(
              ignoring: true,
              child: WebViewWidget(controller: _fallbackWebViewController!),
            ),

            // 2. A 100% transparent hit-test interceptor surface explicitly capturing the click
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior
                    .opaque, // Imperative to catch touches on transparent layers
                onTap: () {
                  debugPrint(
                    "🎯 Fallback HTML view intercepted tap successfully.",
                  );
                  _handleAdClick(
                    ad.actionUrl,
                  ); // Direct routing execution logic catch[cite: 5]
                },
                child: Container(
                  color: Colors
                      .transparent, // Keeps it invisible but completely touchable
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Tier 1: Try loading the standard network image asset path target logic[cite: 3]
    return Image.network(
      ad.assetUrl,
      key: ValueKey<String>("net_${ad.id}"),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          "⚠️ Image network load failed for ${ad.id}. Falling back to HTML container view layer.",
        );
        // TRACK NETWORK LIVE DOWNLOAD FAILURE
        _trackImageLoadFailure(
          ad,
          "Network fallback download error: ${error.toString()}",
        );
        // Use post frame callback to avoid altering state during current build layout phase execution cycles
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _imageFailed = true;
          });
        });

        return Container(
          color: Colors.grey[100],
          child: const Center(
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
