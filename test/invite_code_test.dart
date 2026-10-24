import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/utils/invite_code.dart';
import 'package:fortiva_vpn/widgets/invite_code_dialog.dart';

/// Finding the code in what a friend pasted (clients #271). A friend who
/// installed the APK pastes the whole share message, often in Persian with
/// Persian digits.
void main() {
  const code = 'AB3D7K';

  final files =
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String message(File file, {required String url}) {
    final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return (arb['inviteShareMessage'] as String)
        .replaceAll('{code}', code)
        .replaceAll('{url}', url);
  }

  group('InviteCode.find in every share message', () {
    for (final file in files) {
      final name = file.path.split('/').last;
      test('$name with the link', () {
        final text = message(file, url: 'https://fortivavpn.com/fa/i/$code');
        expect(InviteCode.find(text), code);
      });

      test('$name with the card link', () {
        final text = message(
          file,
          url: 'https://fortivavpn.com/fa/i/$code?s=card',
        );
        expect(InviteCode.find(text), code);
      });

      test('$name when the link carries no code', () {
        // The last line with a code is the one that names it.
        final text = message(file, url: 'https://fortivavpn.com/');
        expect(InviteCode.find(text), code);
      });
    }
  });

  group('InviteCode.find', () {
    test('folds Persian and Arabic digits', () {
      expect(InviteCode.find('کد دعوت من: AB۳D۷K'), code);
      expect(InviteCode.find('رمز دعوتي: AB٣D٧K'), code);
      expect(
        InviteCode.foldDigits('۰۱۲۳۴۵۶۷۸۹ ٠١٢٣٤٥٦٧٨٩'),
        '0123456789 0123456789',
      );
    });

    test('a bare link, with a query or a fragment', () {
      expect(InviteCode.find('https://fortivavpn.com/i/$code'), code);
      expect(InviteCode.find('https://fortivavpn.com/fa/i/$code?s=card'), code);
      expect(InviteCode.find('https://fortivavpn.com/fa/i/$code#x'), code);
      expect(
        InviteCode.find('https://fortivavpn.com/i/${code.toLowerCase()}/'),
        code,
      );
      expect(InviteCode.find('fortivavpn.com/ar-ae/i/$code پیام'), code);
    });

    test('a link whose segment is not a code falls through', () {
      expect(InviteCode.find('https://fortivavpn.com/i/NOTACODE'), isNull);
      expect(
        InviteCode.find(
          'https://fortivavpn.com/i/WRONG1\nMy invite code: $code',
        ),
        code,
      );
    });

    test('a typed code with read-alikes, spaces or a dash', () {
      expect(InviteCode.find('ab3d7k'), code);
      expect(InviteCode.find(' AB3 D7K '), code);
      expect(InviteCode.find('AB3-D7K'), code);
      expect(InviteCode.find('OI3D7K'), '013D7K');
      expect(InviteCode.find('LUXXXX'), '1VXXXX');
    });

    test('takes the last code on the last line that has one', () {
      expect(
        InviteCode.find('ZZ9Q2M\nnothing here\nAB3D7K and QQ2W3E'),
        'QQ2W3E',
      );
      expect(InviteCode.find('AB3D7K\nno code on this line'), code);
    });

    test('a word of the message is never a code', () {
      // "Pasang" is six letters of the alphabet; only upper case counts.
      expect(InviteCode.find('Pasang dari tautan ini'), isNull);
      expect(InviteCode.find('XAB3D7KX'), isNull);
    });

    test('nothing when there is no code', () {
      expect(InviteCode.find(''), isNull);
      expect(InviteCode.find('hello'), isNull);
      expect(
        InviteCode.find('A free VPN that works well for me: Fortiva.'),
        isNull,
      );
      expect(InviteCode.find('ABC'), isNull);
    });
  });

  group('the code field', () {
    TextEditingValue type(InviteCodeFormatter f, String before, String after) =>
        f.formatEditUpdate(
          TextEditingValue(text: before),
          TextEditingValue(
            text: after,
            selection: TextSelection.collapsed(offset: after.length),
          ),
        );

    test('typing folds digits, upper-cases and keeps eight characters', () {
      final pasted = <String?>[];
      final f = InviteCodeFormatter(onPaste: pasted.add);
      expect(type(f, '', 'a').text, 'A');
      expect(type(f, 'AB', 'AB۳').text, 'AB3');
      expect(type(f, 'AB3D7K', 'AB3D7K!').text, 'AB3D7K');
      expect(type(f, 'AB3D7K-1', 'AB3D7K-12').text, 'AB3D7K-1');
      expect(pasted, isEmpty);
    });

    test('a long paste keeps only the code, and says so', () {
      final pasted = <String?>[];
      final f = InviteCodeFormatter(onPaste: pasted.add);
      final value = type(
        f,
        '',
        'یه فیلترشکن رایگان\nاز این لینک نصبش کن:\nhttps://fortivavpn.com/fa/i/AB۳D۷K\nکد دعوت من: AB۳D۷K',
      );
      expect(value.text, code);
      expect(value.selection.baseOffset, code.length);
      expect(pasted, [code]);
    });

    test('a long paste with no code leaves the field empty', () {
      final pasted = <String?>[];
      final f = InviteCodeFormatter(onPaste: pasted.add);
      expect(type(f, '', 'nothing worth reading here').text, '');
      expect(pasted, [null]);
    });
  });
}
