class AdItem {
  final String id;
  final String assetUrl;       // PNG, JPG, or GIF URL
  final String actionUrl;      // Click destination
  final int durationSeconds;   // How long to show this ad (e.g., 5, 8, 12)

  AdItem({
    required this.id,
    required this.assetUrl,
    required this.actionUrl,
    required this.durationSeconds,
  });

  factory AdItem.fromJson(Map<String, dynamic> json) {
    return AdItem(
      id: json['id'] ?? '',
      assetUrl: json['assetUrl'] ?? '',
      actionUrl: json['actionUrl'] ?? '',
      durationSeconds: json['durationSeconds'] ?? 5, // Default fallback to 5 seconds
    );
  }
}