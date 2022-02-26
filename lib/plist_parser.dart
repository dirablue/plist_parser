library plist_parser;

import 'dart:convert' show utf8, base64;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:xml/xml.dart';
import 'package:meta/meta.dart';

class PlistParser {
  // Return an Map object for the given plist format string.
  // It detects if file format is binary or xml automatically
  //
  // Set "typeDetection = false" when you force to use the xml parser
  Map parse(String text, {typeDetection = true}) {
    if (typeDetection && isBinaryTypeText(text)) {
      // binary
      return parseBytes(Uint8List.fromList(text.codeUnits));
    } else {
      // xml
      return parseXml(text);
    }
  }

  // Return an Map object for the given plist format "Uint8List".
  // It detects if file format is binary or xml automatically
  //
  // Set "typeDetection = false" when you force to use the xml parser
  Map parseBytes(Uint8List dataBytes, {typeDetection = true}) {
    if (typeDetection && isBinaryTypeBytes(dataBytes)) {
      // binary
      return parseBinaryBytes(dataBytes);
    } else {
      // xml
      return parseXml(String.fromCharCodes(dataBytes));
    }
  }

  // Synchronously return an Map object for the given the path of plist format file.
  // It detects if file format is binary or xml automatically.
  //
  // Set "typeDetection = false" when you force to use the xml parser.
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
      } catch (e) {
        throw XmlParserException('Invalid data format');
      }
      return parseXml(xml);
    }
  }

  // Return an Map object for the given the path of plist format file.
  // It detects if file format is binary or xml automatically.
  //
  // Set "typeDetection = false" when you force to use the xml parser.
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
        } catch (e) {
          throw XmlParserException('Invalid data format');
        }
        return parseXml(xml);
      }
    });
  }

  // check if text is binary
  isBinaryTypeText(String text) {
    return text.substring(0, 6) == "bplist";
  }

  // check if dataBytes is binary
  isBinaryTypeBytes(Uint8List dataBytes) {
    return String.fromCharCodes(dataBytes.getRange(0, 6)) == "bplist";
  }

  Map parseXml(String xml) {
    var doc = XmlDocument.parse(xml);
    var elements =
        doc.rootElement.children.where(_isElement).cast<XmlElement>();
    if (elements.isEmpty) {
      throw NotFoundException('Not found plist elements');
    }

    return _handleDict(elements.first);
  }

  Map parseXmlFileSync(String path) {
    var file = File(path);
    if (!file.existsSync()) {
      throw NotFoundException('Not found plist file');
    }

    var data = file.readAsStringSync();
    return parse(data);
  }

  Future<Map> parseXmlFile(String path) async {
    var file = File(path);
    if (!await file.exists()) {
      throw NotFoundException('Not found plist file');
    }

    return file.readAsString().then((value) => parse(value));
  }

  Map parseBinaryFileSync(String path) {
    var file = File(path);
    if (!file.existsSync()) {
      throw NotFoundException('Not found plist file');
    }

    var bytes = file.readAsBytesSync();
    return parseBinaryBytes(bytes);
  }

  Future<Map> parseBinaryFile(String path) async {
    var file = File(path);
    if (!await file.exists()) {
      throw NotFoundException('Not found plist file');
    }

    return file.readAsBytes().then((value) => parseBinaryBytes(value));
  }

  Map parseBinaryBytes(Uint8List dataBytes) {
    var trailerStartPos = dataBytes.length - 32;

    // offset table offset size
    var offsetTableOffsetPos = trailerStartPos + 6;
    var offsetTableOffsetSize = _bytesToInt(
        dataBytes.getRange(offsetTableOffsetPos, offsetTableOffsetPos + 1), 1);

    // offset table start ref
    var offsetTableStartPos = _bytesToInt(
        dataBytes.getRange(
            dataBytes.length - offsetTableOffsetSize, dataBytes.length),
        offsetTableOffsetSize);

    // offsetTableStartPos
    var startPos = _bytesToInt(
        dataBytes.getRange(
            offsetTableStartPos, offsetTableStartPos + offsetTableOffsetSize),
        offsetTableOffsetSize);

    var binaryData = _BinaryData(
        bytes: dataBytes,
        offsetTableOffsetSize: offsetTableOffsetSize,
        offsetTableStartPos: offsetTableStartPos,
        startPos: startPos);

    return _handleBinary(binaryData, startPos);
  }

  bool _isElement(XmlNode node) => node.nodeType == XmlNodeType.ELEMENT;

  _handleElem(XmlElement elem) {
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
        return String.fromCharCodes(base64.decode(elem.text));
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

  _handleBinary(_BinaryData binary, int pos) {
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
        return _bytesToInt(binary.bytes.getRange(pos, pos + length), length);

      // real
      case 0x20:
        var length = 1 << (byte & 0xf);
        pos++;
        return _bytesToDouble(
            binary.bytes.getRange(pos, pos + length).toList(), length);

      // date
      case 0x30:
        pos++;
        var seconds =
            _bytesToDouble(binary.bytes.getRange(pos, pos + 8).toList(), 8);
        // 8 bytes to apple epoch time
        var date = DateTime(2001, 1, 1).add(Duration(seconds: seconds.toInt()));
        return date.add(date.timeZoneOffset).toUtc();

      // data
      case 0x40:
        return String.fromCharCodes(
            _getObjectBytes(binary.bytes, byte, pos).bytes);

      // string
      case 0x50:
        return String.fromCharCodes(
            _getObjectBytes(binary.bytes, byte, pos).bytes);

      // unicode
      case 0x60:
        return String.fromCharCodes(
            _getObjectBytes(binary.bytes, byte, pos, unitByte: 2).bytes);

      // array
      case 0xA0:
        List<Object> list = [];
        var itemOffsetList =
            _getObjectBytes(binary.bytes, byte, pos).bytes.toList();
        for (var i = 0; i < itemOffsetList.length; i++) {
          var itemPos = _getObjectStartPos(binary, itemOffsetList[i]);
          var itemValue = _handleBinary(binary, itemPos);
          list.add(itemValue);
        }
        return list;

      // dictionary
      case 0xD0:
        var objectBytes = _getObjectBytes(binary.bytes, byte, pos);
        var objectSize = objectBytes.size;

        var keyOffsetList = objectBytes.bytes.toList();

        var map = {};
        for (var i = 0; i < keyOffsetList.length; i++) {
          // key
          var keyPos = _getObjectStartPos(binary, keyOffsetList[i]);
          var keyName = _handleBinary(binary, keyPos);

          // value
          var valueOffset =
              binary.bytes[pos + objectSize + i + keyOffsetList.length];
          var valuePos = _getObjectStartPos(binary, valueOffset);
          var value = _handleBinary(binary, valuePos);

          map[keyName] = value;
        }
        return map;
    }
    return null;
  }

  @visibleForTesting
  int bytesToInt(Iterable<int> bytes, int byteSize) =>
      _bytesToInt(bytes, byteSize);

  int _bytesToInt(Iterable<int> bytes, int byteSize) {
    if (bytes.length == 0) {
      throw new Exception("bytes list is empty");
    } else if (bytes.length == 1) {
      return bytes.first;
    }

    var byteData = ByteData.view(Uint8List.fromList(bytes.toList()).buffer);

    switch (byteSize) {
      case 1:
        return byteData.getInt8(0);
      case 2:
        return byteData.getInt16(0);
      case 4:
        return byteData.getInt32(0);
      case 8:
        return byteData.getInt64(0);
      default:
        throw new Exception("Undefined ByteSize: ${byteSize}");
    }
  }

  @visibleForTesting
  double bytesToDouble(List<int> bytes, int byteSize) =>
      _bytesToDouble(bytes, byteSize);

  double _bytesToDouble(List<int> bytes, int byteSize) {
    if (bytes.length == 0) {
      throw new Exception("bytes list is empty");
    }

    var byteData = ByteData.view(Uint8List.fromList(bytes).buffer);

    switch (byteSize) {
      case 4:
        return byteData.getFloat32(0);
      case 8:
        return byteData.getFloat64(0);
      default:
        throw new Exception("Undefined ByteSize: $byteSize");
    }
  }

  @visibleForTesting
  _ObjectBytes getObjectBytes(List<int> bytes, int byte, int pos,
          {int unitByte = 1}) =>
      _getObjectBytes(bytes, byte, pos, unitByte: unitByte);

  _ObjectBytes _getObjectBytes(List<int> bytes, int byte, int pos,
      {int unitByte = 1}) {
    var firstPos = pos;
    var length = byte & 0xF;
    if (length == 0xF) {
      // check additional information to detect string length
      pos++;
      var num = bytes[pos] & 0xF;
      var size = pow(2, num).toInt();
      pos++;
      length = _bytesToInt(bytes.getRange(pos, pos + size), size) * unitByte;
      pos += size;
    } else {
      pos++;
    }

    // convert values
    var resultBytes = bytes.getRange(pos, pos + length);
    switch (unitByte) {
      case 1:
        break;
      case 2:
        List<int> newResultBytes = [];
        for (var i = 0; i < resultBytes.length; i++) {
          newResultBytes.add(_bytesToInt(
              [resultBytes.elementAt(i), resultBytes.elementAt(i + 1)], 2));
          i++;
        }
        resultBytes = newResultBytes;
        break;
      default:
        throw new Exception("Undefined unitByte: ${unitByte}");
    }

    return _ObjectBytes(bytes: resultBytes, size: pos - firstPos);
  }

  _getObjectStartPos(_BinaryData binary, int offset) {
    var keyRefPos =
        (binary.offsetTableStartPos) + (binary.offsetTableOffsetSize * offset);

    return _bytesToInt(
        binary.bytes
            .getRange(keyRefPos, keyRefPos + binary.offsetTableOffsetSize),
        binary.offsetTableOffsetSize);
  }
}

class _BinaryData {
  Uint8List bytes = Uint8List(0);
  int offsetTableStartPos = 0;
  int offsetTableOffsetSize = 0;
  int startPos = 0;

  _BinaryData(
      {required this.bytes,
      required this.offsetTableStartPos,
      required this.offsetTableOffsetSize,
      required this.startPos});
}

class _ObjectBytes {
  Iterable<int> bytes = [];
  int size = 0;
  _ObjectBytes({required this.bytes, required this.size});
}

class NotFoundException implements Exception {
  String message;
  NotFoundException(this.message);

  @override
  String toString() => 'NotFoundExceptions: $message';
}
