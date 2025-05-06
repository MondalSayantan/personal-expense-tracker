import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_logger.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // Your GitHub username and repository name
  static const String githubUsername = 'your-github-username';
  static const String repoName = 'expense_tracker';
  
  // Check for updates
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final currentVersion = await _getCurrentVersion();
      final latestRelease = await _getLatestRelease();
      
      if (latestRelease != null && _isNewerVersion(currentVersion, latestRelease['tag_name'])) {
        _showUpdateDialog(context, latestRelease);
      }
    } catch (e) {
      AppLogger.log('Error checking for updates: $e');
    }
  }
  
  // Get current app version
  Future<String> _getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
  
  // Get latest release from GitHub
  Future<Map<String, dynamic>?> _getLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$githubUsername/$repoName/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      AppLogger.log('Error fetching latest release: $e');
    }
    return null;
  }
  
  // Compare versions (simple semver comparison)
  bool _isNewerVersion(String currentVersion, String latestVersion) {
    // Remove 'v' prefix if present
    if (latestVersion.startsWith('v')) {
      latestVersion = latestVersion.substring(1);
    }
    
    final currentParts = currentVersion.split('.');
    final latestParts = latestVersion.split('.');
    
    // Compare major, minor, patch versions
    for (int i = 0; i < math.min(currentParts.length, latestParts.length); i++) {
      final current = int.tryParse(currentParts[i]) ?? 0;
      final latest = int.tryParse(latestParts[i]) ?? 0;
      
      if (latest > current) {
        return true;
      }
      if (latest < current) {
        return false;
      }
    }
    
    // If we get here, check if latest has more version parts
    return latestParts.length > currentParts.length;
  }
  
  // Show update dialog
  void _showUpdateDialog(BuildContext context, Map<String, dynamic> release) {
    final apkAsset = _findApkAsset(release);
    
    if (apkAsset == null) {
      AppLogger.log('No APK found in release');
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version of Expense Tracker is available: ${release['tag_name']}'),
            const SizedBox(height: 8),
            Text('Changes:'),
            const SizedBox(height: 4),
            Text(
              release['body'] ?? 'No release notes available.',
              style: TextStyle(fontSize: 12),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _launchUpdate(apkAsset['browser_download_url']);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
  
  // Find APK asset in release
  Map<String, dynamic>? _findApkAsset(Map<String, dynamic> release) {
    final assets = release['assets'] as List?;
    if (assets == null || assets.isEmpty) return null;
    
    // Find the APK asset
    for (final asset in assets) {
      if (asset['name'].toString().endsWith('.apk')) {
        return asset;
      }
    }
    return null;
  }
  
  // Launch URL to download/install update
  Future<void> _launchUpdate(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      AppLogger.log('Could not launch $url');
    }
  }
}

// No need for a custom math min extension as we're importing dart:math
