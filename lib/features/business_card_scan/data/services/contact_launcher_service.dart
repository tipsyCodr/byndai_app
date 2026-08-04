import 'package:url_launcher/url_launcher.dart';

class ContactLauncherService {
  static String buildMessage({
    required String leadName,
    required String yourName,
    required String yourCompany,
  }) {
    final name = leadName.isNotEmpty ? leadName.split(' ').first : 'there';
    return 'Hi $name, great meeting you! I\'m $yourName from $yourCompany. Looking forward to staying in touch!';
  }

  static Future<bool> sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$cleaned?text=$encoded');
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> sendSMS({
    required String phone,
    required String message,
  }) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('sms:$cleaned?body=${Uri.encodeComponent(message)}');
    return await launchUrl(uri);
  }

  static Future<bool> sendEmail({
    required String email,
    required String subject,
    required String body,
  }) async {
    final uri = Uri.parse(
      'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    return await launchUrl(uri);
  }
}
