import 'dart:convert';

import 'package:flow_reading/domain/services/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches standard SHA-256 vectors', () {
    expect(
      sha256Hex(const []),
      'e3b0c44298fc1c149afbf4c8996fb924'
      '27ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223'
      'b00361a396177a9cb410ff61f20015ad',
    );
  });
}
