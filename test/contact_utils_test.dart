import 'package:flutter_test/flutter_test.dart';
import 'package:nook/utils/contact_utils.dart';

void main() {
  group('dialNumber', () {
    test('keeps digits and a leading plus only', () {
      expect(ContactUtils.dialNumber('+91 98765-43210'), '+919876543210');
      expect(ContactUtils.dialNumber('(098) 765 43210'), '09876543210');
    });
    test('rejects empty, too short and too long values', () {
      expect(ContactUtils.dialNumber(null), isNull);
      expect(ContactUtils.dialNumber('  '), isNull);
      expect(ContactUtils.dialNumber('1234'), isNull);
      expect(ContactUtils.dialNumber('1234567890123456'), isNull);
    });
  });

  group('whatsappNumber', () {
    test('handles international formats', () {
      expect(ContactUtils.whatsappNumber('+91 98765 43210'), '919876543210');
      expect(ContactUtils.whatsappNumber('0091 98765 43210'), '919876543210');
    });
    test('adds the default country code to local 10-digit numbers', () {
      expect(ContactUtils.whatsappNumber('98765 43210'), '919876543210');
      expect(ContactUtils.whatsappNumber('098765 43210'), '919876543210');
      expect(ContactUtils.whatsappNumber('98765 43210', defaultCountryCode: '44'), '449876543210');
    });
    test('leaves numbers that already look international alone', () {
      expect(ContactUtils.whatsappNumber('919876543210'), '919876543210');
      expect(ContactUtils.whatsappNumber('63259521223'), '63259521223');
    });
    test('returns null for unusable input', () {
      expect(ContactUtils.whatsappNumber('abc'), isNull);
    });
  });

  group('uris', () {
    test('tel', () {
      expect(ContactUtils.telUri('+91 98765 43210').toString(), 'tel:+919876543210');
      expect(ContactUtils.telUri(''), isNull);
    });
    test('whatsapp encodes the message', () {
      final uri = ContactUtils.whatsappUri('9876543210', 'Hi there & thanks');
      expect(uri.toString(), 'https://wa.me/919876543210?text=Hi%20there%20%26%20thanks');
    });
    test('mailto encodes spaces as %20, not +', () {
      final uri = ContactUtils.mailUri('a@b.com', subject: 'Lost item', body: 'Hi there');
      expect(uri.toString(), 'mailto:a@b.com?subject=Lost%20item&body=Hi%20there');
    });
    test('mailto rejects invalid addresses', () {
      expect(ContactUtils.mailUri('not-an-email'), isNull);
      expect(ContactUtils.mailUri(null), isNull);
    });
  });

  test('contactMessage is worded for the listing type', () {
    expect(ContactUtils.contactMessage(itemType: 'LOST', title: 'Wallet'), contains('lost item "Wallet"'));
    expect(ContactUtils.contactMessage(itemType: 'FOUND', title: 'Wallet'), contains('found item "Wallet"'));
  });

  group('timeAgo', () {
    final now = DateTime(2026, 11, 8, 12);
    test('buckets', () {
      expect(ContactUtils.timeAgo(now.subtract(const Duration(seconds: 10)), now: now), 'Just now');
      expect(ContactUtils.timeAgo(now.add(const Duration(minutes: 3)), now: now), 'Just now');
      expect(ContactUtils.timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(ContactUtils.timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3 hr ago');
      expect(ContactUtils.timeAgo(now.subtract(const Duration(days: 1)), now: now), '1 day ago');
      expect(ContactUtils.timeAgo(now.subtract(const Duration(days: 4)), now: now), '4 days ago');
      expect(ContactUtils.timeAgo(now.subtract(const Duration(days: 15)), now: now), '2 wk ago');
      expect(ContactUtils.timeAgo(now.subtract(const Duration(days: 90)), now: now), '3 mo ago');
      expect(ContactUtils.timeAgo(now.subtract(const Duration(days: 800)), now: now), '2 yr ago');
    });
  });
}
