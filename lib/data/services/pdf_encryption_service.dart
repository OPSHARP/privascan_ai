// ignore_for_file: implementation_imports
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/format/num.dart';
import 'package:pdf/src/pdf/format/string.dart';
import 'package:pdf/src/pdf/format/object_base.dart';

/// RC4 Stream Cipher for PDF Standard Encryption (Revision 2 & 3).
class Rc4Cipher {
  final Uint8List _s = Uint8List(256);
  int _i = 0;
  int _j = 0;

  Rc4Cipher(Uint8List key) {
    for (var i = 0; i < 256; i++) {
      _s[i] = i;
    }
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + _s[i] + key[i % key.length]) & 0xFF;
      final temp = _s[i];
      _s[i] = _s[j];
      _s[j] = temp;
    }
  }

  Uint8List process(Uint8List data) {
    final out = Uint8List(data.length);
    var i = _i;
    var j = _j;
    for (var x = 0; x < data.length; x++) {
      i = (i + 1) & 0xFF;
      j = (j + _s[i]) & 0xFF;
      final temp = _s[i];
      _s[i] = _s[j];
      _s[j] = temp;
      out[x] = data[x] ^ _s[(_s[i] + _s[j]) & 0xFF];
    }
    _i = i;
    _j = j;
    return out;
  }
}

/// Standard PDF Password Encryption (ISO 32000-1 / PDF 1.7 Standard Security Handler Rev 3, 128-bit).
/// Enables password-protected PDFs that prompt for password in Adobe Acrobat,
/// Google Drive, Chrome, Apple Books, and Android PDF viewers.
class StandardPdfEncryption extends PdfEncryption {
  static const List<int> _padding = [
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41,
    0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
    0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
    0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
  ];

  final Uint8List _encryptionKey;

  StandardPdfEncryption._(
    super.pdfDocument, {
    required Uint8List oBytes,
    required Uint8List uBytes,
    required Uint8List encryptionKey,
    required int permissions,
  })  : _encryptionKey = encryptionKey {
    params['/Filter'] = const PdfName('/Standard');
    params['/V'] = const PdfNum(2); // V 2: 128-bit
    params['/R'] = const PdfNum(3); // Revision 3
    params['/Length'] = const PdfNum(128);
    params['/P'] = PdfNum(permissions);
    params['/O'] = PdfString(oBytes, format: PdfStringFormat.binary);
    params['/U'] = PdfString(uBytes, format: PdfStringFormat.binary);
  }

  /// Creates and attaches standard PDF encryption with user password to the document.
  factory StandardPdfEncryption.create(
    PdfDocument document, {
    required String userPassword,
    String? ownerPassword,
    int permissions = -3904, // Default: allow print, copy, accessibility
  }) {
    final ownerPass = ownerPassword ?? userPassword;
    final docId = document.documentID;

    // 1. Compute /O entry
    final oBytes = _computeOwnerHash(ownerPass, userPassword);

    // 2. Compute Encryption Key
    final encryptionKey = _computeEncryptionKey(
      userPassword: userPassword,
      oBytes: oBytes,
      permissions: permissions,
      documentId: docId,
    );

    // 3. Compute /U entry
    final uBytes = _computeUserHash(
      encryptionKey: encryptionKey,
      documentId: docId,
    );

    final enc = StandardPdfEncryption._(
      document,
      oBytes: oBytes,
      uBytes: uBytes,
      encryptionKey: encryptionKey,
      permissions: permissions,
    );

    document.encryption = enc;
    return enc;
  }

  static Uint8List _padPassword(String password) {
    final passBytes = password.codeUnits;
    final out = Uint8List(32);
    final len = passBytes.length < 32 ? passBytes.length : 32;
    for (var i = 0; i < len; i++) {
      out[i] = passBytes[i];
    }
    for (var i = len; i < 32; i++) {
      out[i] = _padding[i - len];
    }
    return out;
  }

  static Uint8List _computeOwnerHash(String ownerPass, String userPass) {
    final paddedOwner = _padPassword(ownerPass);
    var hash = md5.convert(paddedOwner).bytes;

    // 50 iterations of MD5 for Rev 3
    for (var i = 0; i < 50; i++) {
      hash = md5.convert(hash).bytes;
    }

    final key = Uint8List.fromList(hash.sublist(0, 16));
    var result = _padPassword(userPass);

    final rc4 = Rc4Cipher(key);
    result = rc4.process(result);

    for (var i = 1; i <= 19; i++) {
      final iterKey = Uint8List(16);
      for (var j = 0; j < 16; j++) {
        iterKey[j] = key[j] ^ i;
      }
      result = Rc4Cipher(iterKey).process(result);
    }

    return result;
  }

  static Uint8List _computeEncryptionKey({
    required String userPassword,
    required Uint8List oBytes,
    required int permissions,
    required Uint8List documentId,
  }) {
    final paddedUser = _padPassword(userPassword);
    final permBytes = Uint8List(4)
      ..buffer.asByteData().setInt32(0, permissions, Endian.little);

    final data = <int>[
      ...paddedUser,
      ...oBytes,
      ...permBytes,
      ...documentId,
    ];

    var hash = md5.convert(data).bytes;

    // 50 iterations of MD5
    for (var i = 0; i < 50; i++) {
      hash = md5.convert(hash.sublist(0, 16)).bytes;
    }

    return Uint8List.fromList(hash.sublist(0, 16));
  }

  static Uint8List _computeUserHash({
    required Uint8List encryptionKey,
    required Uint8List documentId,
  }) {
    final data = <int>[
      ..._padding,
      ...documentId,
    ];
    final uHash = Uint8List.fromList(md5.convert(data).bytes);

    var result = Rc4Cipher(encryptionKey).process(uHash);

    for (var i = 1; i <= 19; i++) {
      final iterKey = Uint8List(16);
      for (var j = 0; j < 16; j++) {
        iterKey[j] = encryptionKey[j] ^ i;
      }
      result = Rc4Cipher(iterKey).process(result);
    }

    // Pad to 32 bytes with zeros
    final out = Uint8List(32);
    out.setRange(0, 16, result);
    return out;
  }

  @override
  Uint8List encrypt(Uint8List input, PdfObjectBase object) {
    final objNum = object.objser;
    final objGen = object.objgen;

    final keyData = <int>[
      ..._encryptionKey,
      objNum & 0xFF,
      (objNum >> 8) & 0xFF,
      (objNum >> 16) & 0xFF,
      objGen & 0xFF,
      (objGen >> 8) & 0xFF,
    ];

    final objKeyHash = md5.convert(keyData).bytes;
    final objKey = Uint8List.fromList(objKeyHash.sublist(0, 16));

    final cipher = Rc4Cipher(objKey);
    return cipher.process(input);
  }
}
