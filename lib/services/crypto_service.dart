import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Required for debugPrint
import 'package:pointycastle/export.dart';
// Keep the alias to avoid class conflicts
import 'package:asn1lib/asn1lib.dart' as asn1;
import 'package:encrypt/encrypt.dart' as encrypt;

class CryptoService {
  late RSAPrivateKey _privateKey;
  late RSAPublicKey _publicKey;

  CryptoService() {
    _generateKeyPair();
  }

  void _generateKeyPair() {
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        SecureRandom('Fortuna')..seed(KeyParameter(_seed())),
      ));

    final pair = keyGen.generateKeyPair();
    _privateKey = pair.privateKey as RSAPrivateKey;
    _publicKey = pair.publicKey as RSAPublicKey;
  }

  Uint8List _seed() {
    final random = SecureRandom('Fortuna');
    final seeds = List<int>.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256);
    random.seed(KeyParameter(Uint8List.fromList(seeds)));
    return random.nextBytes(32);
  }

  String getPublicKeyPem() {
    final algorithmSeq = asn1.ASN1Sequence();
    final algorithmAsn1Obj = asn1.ASN1Object.fromBytes(Uint8List.fromList([0x6, 0x9, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0xd, 0x1, 0x1, 0x1]));
    final paramsAsn1Obj = asn1.ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
    algorithmSeq.add(algorithmAsn1Obj);
    algorithmSeq.add(paramsAsn1Obj);

    final publicKeySeq = asn1.ASN1Sequence();
    // Add '!' to ensure BigInt is not null
    publicKeySeq.add(asn1.ASN1Integer(_publicKey.modulus!));
    publicKeySeq.add(asn1.ASN1Integer(_publicKey.exponent!));

    // encodedBytes is a getter
    final publicKeySeqBitString = asn1.ASN1BitString(Uint8List.fromList(publicKeySeq.encodedBytes));

    final topLevelSeq = asn1.ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeySeqBitString);

    final dataBase64 = base64.encode(topLevelSeq.encodedBytes);
    return '-----BEGIN PUBLIC KEY-----\n$dataBase64\n-----END PUBLIC KEY-----';
  }

  RSAPublicKey loadPublicKey(String pem) {
    try {
      final rows = pem.split('\n').where((row) => !row.contains('BEGIN') && !row.contains('END')).join('');
      final keyBytes = base64.decode(rows);
      final asn1Parser = asn1.ASN1Parser(Uint8List.fromList(keyBytes));
      final topLevelSeq = asn1Parser.nextObject() as asn1.ASN1Sequence;

      // The second element is the BitString containing the public key
      final publicKeyBitString = topLevelSeq.elements![1] as asn1.ASN1BitString;

      // The first byte of a BitString value is the "unused bits" count.
      // We must skip it (sublist(1)) to get to the actual Sequence start (0x30).
      final rawBytes = publicKeyBitString.valueBytes();
      final contentBytes = Uint8List.fromList(rawBytes.sublist(1));

      final publicKeyAsn = asn1.ASN1Parser(contentBytes);
      final publicKeySeq = publicKeyAsn.nextObject() as asn1.ASN1Sequence;

      // Decode bytes to BigInt manually to avoid property ambiguity
      final modulusObj = publicKeySeq.elements![0] as asn1.ASN1Integer;
      final exponentObj = publicKeySeq.elements![1] as asn1.ASN1Integer;

      final modulus = _bytesToBigInt(modulusObj.valueBytes());
      final exponent = _bytesToBigInt(exponentObj.valueBytes());

      return RSAPublicKey(modulus, exponent);
    } catch (e) {
      debugPrint('Error parsing Public Key: $e');
      rethrow;
    }
  }

  // Helper to convert bytes to BigInt (unsigned)
  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  Map<String, String> encryptMessage(String message, RSAPublicKey peerPublicKey) {
    final key = encrypt.Key.fromSecureRandom(32);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final iv = encrypt.IV.fromSecureRandom(16);

    final encryptedMessage = encrypter.encrypt(message, iv: iv);

    final cipher = RSAEngine()..init(true, PublicKeyParameter<RSAPublicKey>(peerPublicKey));
    final encryptedKey = cipher.process(key.bytes);

    return {
      'enc_msg': base64.encode(encryptedMessage.bytes),
      'enc_key': base64.encode(encryptedKey),
      'iv': base64.encode(iv.bytes),
    };
  }

  String decryptMessage(Map<String, dynamic> package) {
    final encryptedKey = base64.decode(package['enc_key']);
    final encryptedMsg = base64.decode(package['enc_msg']);
    final iv = encrypt.IV(base64.decode(package['iv']));

    final cipher = RSAEngine()..init(false, PrivateKeyParameter<RSAPrivateKey>(_privateKey));
    final keyBytes = cipher.process(Uint8List.fromList(encryptedKey));

    final key = encrypt.Key(keyBytes);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final decrypted = encrypter.decrypt(encrypt.Encrypted(Uint8List.fromList(encryptedMsg)), iv: iv);

    return decrypted;
  }
}