library plist_parser;

import 'dart:convert' show utf8, base64;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

class PlistParser {
  /// Return an Map object for the given plist format string.
  /// It detects if file format is binary or xml automatically
  ///
  /// Set "typeDetection = false" when you force to use the xml parser
  Map parse(String text, {typeDetection = true}) {
    if (typeDetection && isBinaryTypeText(text)) {
      // binary
      return parseBytes(Uint8List.fromList(text.codeUnits));
    } else {
      // xml
      return parseXml(text);
    }
  }

  /// Return an Map object for the given plist format "Uint8List".
  /// It detects if file format is binary or xml automatically
  ///
  /// Set "typeDetection = false" when you force to use the xml parser
  Map parseBytes(Uint8List dataBytes, {typeDetection = true}) {
    if (typeDetection && isBinaryTypeBytes(dataBytes)) {
      // binary
      return parseBinaryBytes(dataBytes);
    } else {
      // xml
      return parseXml(String.fromCharCodes(dataBytes));
    }
  }

  /// Synchronously return an Map object for the given the path of
  /// plist format file.
  /// It detects if file format is binary or xml automatically.
  ///
  /// Set "typeDetection = false" when you force to use the xml parser.
  Map parseFileSync(String path, {typeDetection = true}) {
    var file = File(path);
    if (!file.existsSync()) {
      throw NotFoundException('Not found plist file');
    }

    var dataBytes = file.readAsBytesSync();
    if (typeDetection && isBinaryTypeBytes(dataBytes)) {
      return parseBinaryBytes(dataBytes);
    } else {
      var xml = '';
      try {
        xml = utf8.decode(String.fromCharCodes(dataBytes).runes.toList());
      } on Exception catch (e) {
        throw XmlParserException('Invalid data format. $e');
      }
      return parseXml(xml);
    }
  }

  /// Return an Map object for the given the path of plist format file.
  /// It detects if file format is binary or xml automatically.
  ///
  /// Set "typeDetection = false" when you force to use the xml parser.
  Future<Map> parseFile(String path, {typeDetection = true}) async {
    var file = File(path);
    if (!await file.exists()) {
      throw NotFoundException('Not found plist file');
    }

    return file.readAsBytes().then((dataBytes) {
      if (typeDetection && isBinaryTypeBytes(dataBytes)) {
        return parseBinaryBytes(dataBytes);
      } else {
        var xml = '';
        try {
          xml = utf8.decode(String.fromCharCodes(dataBytes).runes.toList());
        } on Exception catch (e) {
          throw XmlParserException('Invalid data format. $e');
        }
        return parseXml(xml);
      }
    });
  }

  static final _whitespaceReg = RegExp(r'\s+');

  static const _bplist = "bplist";

  /// check if text is binary
  isBinaryTypeText(String text) {
    return text.substring(0, 6) == _bplist;
  }

  /// check if dataBytes is binary
  isBinaryTypeBytes(Uint8List dataBytes) {
    return String.fromCharCodes(dataBytes.getRange(0, 6)) == _bplist;
  }

  /// Return an Map object for the given the path of XML plist format string.
  Map parseXml(String xml) {
    Iterable<XmlElement> elements;
    try {
      var doc = XmlDocument.parse(xml);
      elements = doc.rootElement.children.where(_isElement).cast<XmlElement>();
    } on Error catch (e) {
      throw XmlParserException(e.toString());
    }
    if (elements.isEmpty) {
      throw NotFoundException('Not found plist elements');
    }

    return _handleDict(elements.first);
  }

  /// Synchronously return an Map object for the given the path of
  /// XML plist format file.
  Map parseXmlFileSync(String path) {
    var file = File(path);
    if (!file.existsSync()) {
      throw NotFoundException('Not found plist file');
    }

    var data = file.readAsStringSync();
    return parse(data);
  }

  /// Return an Map object for the given the path of XML plist format file.
  Future<Map> parseXmlFile(String path) async {
    var file = File(path);
    if (!await file.exists()) {
      throw NotFoundException('Not found plist file');
    }

    return file.readAsString().then((value) => parse(value));
  }

  /// Synchronously return an Map object for the given the path of
  /// Binary plist format file.
  Map parseBinaryFileSync(String path) {
    var file = File(path);
    if (!file.existsSync()) {
      throw NotFoundException('Not found plist file');
    }

    var bytes = file.readAsBytesSync();
    return parseBinaryBytes(bytes);
  }

  /// Return an Map object for the given the path of Binary plist format file.
  Future<Map> parseBinaryFile(String path) async {
    var file = File(path);
    if (!await file.exists()) {
      throw NotFoundException('Not found plist file');
    }

    return file.readAsBytes().then((value) => parseBinaryBytes(value));
  }

  /// Return an Map object for the given the path of Binary plist format bytes.
  Map parseBinaryBytes(Uint8List dataBytes) {
    // Only bplist00 format is supported
    if (String.fromCharCodes(dataBytes.getRange(0, 8)) != "bplist00") {
      throw UnimplementedError("Invalid binary plist format");
    }

    final trailerBytes = dataBytes.buffer.asByteData(dataBytes.length - 32);

    // offset table offset size
    var offsetTableOffsetSize = trailerBytes.getUint8(6);

    // object ref size
    var objectRefSize = trailerBytes.getUint8(7);

    // offset table start ref
    var offsetTableStartPos = trailerBytes.getUint64(24);

    // offsetTableStartPos
    var startPos = trailerBytes.getUint64(16);

    var binaryData = _BinaryData(
        bytes: dataBytes,
        offsetTableOffsetSize: offsetTableOffsetSize,
        offsetTableStartPos: offsetTableStartPos,
        objectRefSize: objectRefSize);

    return _handleBinary(binaryData, _getObjectStartPos(binaryData, startPos));
  }

  bool _isElement(XmlNode node) => node.nodeType == XmlNodeType.ELEMENT;

  dynamic _handleElem(XmlElement elem) {
    switch (elem.name.local) {
      case 'string':
        return elem.text;
      case 'real':
        return double.parse(elem.text);
      case 'integer':
        return int.parse(elem.text);
      case 'true':
        return true;
      case 'false':
        return false;
      case 'date':
        return DateTime.parse(elem.text);
      case 'data':
        return String.fromCharCodes(
            base64.decode(elem.text.replaceAll(_whitespaceReg, '')));
      case 'array':
        return elem.children
            .where(_isElement)
            .cast<XmlElement>()
            .map((el) => _handleElem(el))
            .toList();
      case 'dict':
        return _handleDict(elem);
      default:
        return null;
    }
  }

  Map _handleDict(XmlElement elem) {
    var children = elem.children.where(_isElement).cast<XmlElement>();

    var keys =
        children.where((el) => el.name.local == 'key').map((el) => el.text);

    var values = children
        .where((el) => el.name.local != 'key')
        .map((el) => _handleElem(el));
    return Map.fromIterables(keys, values);
  }

  dynamic _handleBinary(_BinaryData binary, int pos) {
    var byte = binary.bytes[pos];
    switch (byte & 0xF0) {
      // bool
      case 0x00:
        if (byte == 0x08) {
          return false;
        } else if (byte == 0x09) {
          return true;
        }
        break;

      // integer
      case 0x10:
        var length = 1 << (byte & 0xf);
        pos++;
        // Signed integers are always stored with 8 bytes
        return _bytesToInt(binary.bytes.buffer.asByteData(pos, length), length,
            signed64Bit: true);

      // real
      case 0x20:
        var length = 1 << (byte & 0xf);
        pos++;
        return _bytesToDouble(
            binary.bytes.buffer.asByteData(pos, length), length);

      // date
      case 0x30:
        pos++;
        var seconds = _bytesToDouble(binary.bytes.buffer.asByteData(pos, 8), 8);
        // 8 bytes to apple epoch time
        var date = DateTime(2001).add(Duration(seconds: seconds.toInt()));
        return date.add(date.timeZoneOffset).toUtc();

      // data
      case 0x40:
        final byteData = _getObjectDataBytes(binary.bytes, byte, pos);
        return binary.bytes.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

      // string
      case 0x50:
        final byteData = _getObjectDataBytes(binary.bytes, byte, pos);
        return String.fromCharCodes(binary.bytes.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

      // unicode
      case 0x60:
        final byteData =
            _getObjectDataBytes(binary.bytes, byte, pos, unitByte: 2);
        final stringBuilder = StringBuffer();

        // UTF16-be decode
        for (var i = 0; i < byteData.lengthInBytes; i += 2) {
          stringBuilder.writeCharCode(byteData.getUint16(i));
        }

        return stringBuilder.toString();

      // array
      case 0xA0:
        List<Object> list = [];
        final byteData = _getObjectDataBytes(binary.bytes, byte, pos,
            unitByte: binary.objectRefSize);

        for (var i = 0; i < byteData.lengthInBytes; i += binary.objectRefSize) {
          var itemPos = _getObjectStartPos(
              binary, _bytesToInt(byteData, binary.objectRefSize, offset: i));
          var itemValue = _handleBinary(binary, itemPos);
          list.add(itemValue);
        }
        return list;

      // dictionary
      case 0xD0:
        final byteData = _getObjectDataBytes(binary.bytes, byte, pos,
            unitByte: binary.objectRefSize, sizeScale: 2);

        var map = {};
        var keySize = byteData.lengthInBytes ~/ (2 * binary.objectRefSize);
        for (var i = 0; i < keySize; i++) {
          // key
          var keyPos = _getObjectStartPos(
              binary,
              _bytesToInt(byteData, binary.objectRefSize,
                  offset: i * binary.objectRefSize));
          var keyName = _handleBinary(binary, keyPos);

          var valuePos = _getObjectStartPos(
              binary,
              _bytesToInt(byteData, binary.objectRefSize,
                  offset: (i + keySize) * binary.objectRefSize));
          var value = _handleBinary(binary, valuePos);

          map[keyName] = value;
        }
        return map;
    }
    return null;
  }

  @visibleForTesting
  int bytesToInt(ByteData bytes, int byteSize, {int offset = 0}) =>
      _bytesToInt(bytes, byteSize, offset: offset);

  int _bytesToInt(ByteData byteData, int byteSize,
      {int offset = 0, bool signed64Bit = false}) {
    if (byteData.lengthInBytes < byteSize) {
      throw Exception("bytes list size is invalid");
    }

    switch (byteSize) {
      case 1:
        return byteData.getUint8(offset);
      case 2:
        return byteData.getUint16(offset);
      case 4:
        return byteData.getUint32(offset);
      case 8:
        if (signed64Bit) {
          return byteData.getInt64(offset);
        } else {
          return byteData.getUint64(offset);
        }
      default:
        throw Exception("Undefined ByteSize: $byteSize");
    }
  }

  @visibleForTesting
  double bytesToDouble(ByteData bytes, int byteSize) =>
      _bytesToDouble(bytes, byteSize);

  double _bytesToDouble(ByteData byteData, int byteSize) {
    if (byteData.lengthInBytes == 0) {
      throw Exception("bytes list is empty");
    }

    switch (byteSize) {
      case 4:
        return byteData.getFloat32(0);
      case 8:
        return byteData.getFloat64(0);
      default:
        throw Exception("Undefined ByteSize: $byteSize");
    }
  }

  ByteData _getObjectDataBytes(Uint8List bytes, int byte, int pos,
      {int unitByte = 1, int sizeScale = 1}) {
    var length = byte & 0xF;
    if (length == 0xF) {
      // check additional information to detect string length
      pos++;
      var num = bytes[pos] & 0xF;
      var size = pow(2, num).toInt();
      pos++;
      length = _bytesToInt(bytes.buffer.asByteData(pos, size), size) *
          unitByte *
          sizeScale;
      pos += size;
    } else {
      length *= (unitByte * sizeScale);
      pos++;
    }

    return bytes.buffer.asByteData(pos, length);
  }

  int _getObjectStartPos(_BinaryData binary, int offset) {
    var keyRefPos =
        (binary.offsetTableStartPos) + (binary.offsetTableOffsetSize * offset);

    return _bytesToInt(
        binary.bytes.buffer.asByteData(keyRefPos, binary.offsetTableOffsetSize),
        binary.offsetTableOffsetSize);
  }
}

class _BinaryData {
  Uint8List bytes = Uint8List(0);
  int offsetTableStartPos = 0;
  int offsetTableOffsetSize = 0;
  int objectRefSize = 0;

  _BinaryData({
    required this.bytes,
    required this.offsetTableStartPos,
    required this.offsetTableOffsetSize,
    required this.objectRefSize,
  });
}

class NotFoundException implements Exception {
  String message;

  NotFoundException(this.message);

  @override
  String toString() => 'NotFoundExceptions: $message';
}
