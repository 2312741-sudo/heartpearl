import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  // App official URLs & Contacts
  static const String privacyPolicyUrl =
      'https://tamchau-865f3.web.app/privacy-policy.html';
  static const String eulaUrl =
      'https://tamchau-865f3.web.app/eula.html';
  static const String deleteAccountUrl =
      'https://tamchau-865f3.web.app/delete-account.html';
  static const String webPortalUrl =
      'https://tamchau-865f3.web.app';
  static const String supportEmail =
      'nthanhtam.402@gmail.com';

  /// Opens a web URL in the device's default web browser.
  static Future<bool> openUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString.trim());
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error launching url: $e');
      return false;
    }
  }

  /// Opens the device mail app with pre-filled recipient, subject, and body.
  static Future<bool> openEmail({
    required String email,
    String? subject,
    String? body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      query: (subject != null || body != null)
          ? [
              if (subject != null) 'subject=${Uri.encodeComponent(subject)}',
              if (body != null) 'body=${Uri.encodeComponent(body)}',
            ].join('&')
          : null,
    );

    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('Error launching mailto: $e');
      return false;
    }
  }

  /// Convenience launchers
  static Future<bool> openPrivacyPolicy() => openUrl(privacyPolicyUrl);
  static Future<bool> openEula() => openUrl(eulaUrl);
  static Future<bool> openDeleteAccount() => openUrl(deleteAccountUrl);
  static Future<bool> openWebPortal() => openUrl(webPortalUrl);
  static Future<bool> openSupport({String? subject, String? body}) =>
      openEmail(email: supportEmail, subject: subject, body: body);
}
