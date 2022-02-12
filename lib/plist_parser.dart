library plist_parser;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:xml/xml.dart';

class PlistParser {

  // Return an Map object for the given input string,
  // or throws an XmlParserException or an ArgumentError if the input is invalid
  Map parse(String xml) {
    var doc = XmlDocument.parse(xml);
    var elements = doc.rootElement.children.where(_isElement).cast<XmlElement>();
    if (elements.isEmpty) {
      throw NotFoundException('Not found plist elements');
    }

    return _handleDict(elements.first);
  }

  Map parseFileSync(String path) {
    var file = File(path);
    if (!file.existsSync()) {
      throw NotFoundException('Not found plist file');
    }

    var data = file.readAsStringSync();
    return parse(data);
  }

  Future<Map> parseFile(String path) async {
    var file = File(path);
    if (!await file.exists()) {
      throw NotFoundException('Not found plist file');
    }

    return file.readAsString().then((value) => parse(value));
  }

  Future<Map> parseBinaryFile(String path) async {
    var file = File(path);
    if (!await file.exists()) {
      throw NotFoundException('Not found plist file');
    }

    return file.readAsBytes().then((value) => parseBinaryBytes(value));
  }

  Map parseBinaryFileSync(String path) {
    var file = File(path);
    var bytes = file.readAsBytesSync();
    return parseBinaryBytes(bytes);
  }

  Map parseBinaryBytes(Uint8List dataBytes) {
    var trailerStartPos = dataBytes.length - 32;

    // offset table offset size
    var offsetTableOffsetPos = trailerStartPos + 6;
    var offsetTableOffsetSize = _bytesToInt(
        dataBytes.getRange(offsetTableOffsetPos, offsetTableOffsetPos + 1), 1);

    // offset table start ref
    var offsetTableStartPos = _bytesToInt(
        dataBytes.getRange(dataBytes.length - offsetTableOffsetSize, dataBytes.length),
        offsetTableOffsetSize
    );

    // offsetTableStartPos
    var startPos = _bytesToInt(
        dataBytes.getRange(offsetTableStartPos, offsetTableStartPos + offsetTableOffsetSize),
        offsetTableOffsetSize
    );

    var binaryData = BinaryData(
        bytes: dataBytes,
        offsetTableOffsetSize: offsetTableOffsetSize,
        offsetTableStartPos: offsetTableStartPos,
        startPos: startPos
    );

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

    var keys = children
        .where((el) => el.name.local == 'key')
        .map((el) => el.text);

    var values = children
        .where((el) => el.name.local != 'key')
        .map((el) => _handleElem(el));
    return Map.fromIterables(keys, values);
  }

  _handleBinary(BinaryData binary, int pos) {
    var byte = binary.bytes[pos];
    switch (byte & 0xF0) {
      // bool
      case 0x00:
        if (byte == 0x08) {
          return true;
        } else if (byte == 0x09) {
          return false;
        } else {
          throw Exception("Unknown bool byte encountered: $byte");
        }

      // integer
      case 0x10:
        var length = 1 << (byte & 0xf);
        pos++;
        return _bytesToInt(
            binary.bytes.getRange(pos, pos + length), length);

      // real
      case 0x20:
        var length = 1 << (byte & 0xf);
        pos++;
        return _bytesToDouble(
            binary.bytes.getRange(pos, pos + length).toList(), length);

      // date
      case 0x30:
        pos++;
        var seconds = _bytesToDouble(
            binary.bytes.getRange(pos, pos + 8).toList(), 8);
        // 8 bytes to apple epoch time
        return DateTime(2001, 1, 1).add(Duration(seconds: seconds.toInt()));

      // data
      case 0x40:
        return String.fromCharCodes(_getObjectBytes(binary.bytes, byte, pos));

      // string
      case 0x50:
        return String.fromCharCodes(_getObjectBytes(binary.bytes, byte, pos));

      // array
      case 0xA0:
        List<Object> list = [];
        var itemOffsetList = _getObjectBytes(binary.bytes, byte, pos).toList();
        for (var i = 0; i < itemOffsetList.length; i++) {
          var itemPos = _getObjectStartPos(binary, itemOffsetList[i]);
          var itemValue = _handleBinary(binary, itemPos);
          list.add(itemValue);
        }
        return list;

      // dictionary
      case 0xD0:
        var keyOffsetList = _getObjectBytes(binary.bytes, byte, pos).toList();

        var map = {};
        for (var i = 0; i < keyOffsetList.length; i++) {
          // key
          var keyPos = _getObjectStartPos(binary, keyOffsetList[i]);
          var keyName = _handleBinary(binary, keyPos);

          // value
          var valueOffset = binary.bytes[pos + 1 + i + keyOffsetList.length];
          var valuePos = _getObjectStartPos(binary, valueOffset);
          var value = _handleBinary(binary, valuePos);

          map[keyName] = value;
        }
        return map;
    }
    return null;
  }

  int _bytesToInt(Iterable<int> bytes, int byteSize) {
    if (bytes.length == 0) {
      throw new Exception("bytes list is empty");
    }
    else if (bytes.length == 1) {
      return bytes.first;
    }

    var byteData = ByteData.view(Uint8List.fromList(bytes.toList()).buffer);

    switch (byteSize) {
      case 1: return byteData.getInt8(0);
      case 2: return byteData.getInt16(0);
      case 4: return byteData.getInt32(0);
      case 8: return byteData.getInt64(0);
      default:
        throw new Exception("Undefined ByteSize: ${byteSize}");
    }
  }

  double _bytesToDouble(List<int> bytes, int byteSize) {
    if (bytes.length == 0) {
      throw new Exception("bytes list is empty");
    }

    var byteData = ByteData.view(Uint8List.fromList(bytes).buffer);

    switch (byteSize) {
      case 4: return byteData.getFloat32(0);
      case 8: return byteData.getFloat64(0);
      default:
        throw new Exception("Undefined ByteSize: $byteSize");
    }
  }

  Iterable<int> _getObjectBytes(List<int> bytes, int byte, int pos) {
    var length = byte & 0xF;
    if (length == 0xF) {
      // check additional information to detect string length
      pos++;
      var num = bytes[pos] & 0xF;
      var size = pow(2, num).toInt();
      pos++;
      length = _bytesToInt(bytes.getRange(pos, pos + size), size);
      pos += size;
    } else {
      pos++;
    }

    return bytes.getRange(pos, pos + length);
  }

  _getObjectStartPos(BinaryData binary, int offset) {
    var keyRefPos = (binary.offsetTableStartPos) +
        (binary.offsetTableOffsetSize * offset);

    return _bytesToInt(
        binary.bytes.getRange(keyRefPos, keyRefPos + binary.offsetTableOffsetSize),
        binary.offsetTableOffsetSize
    );
  }

}

class BinaryData {
  Uint8List bytes = Uint8List(0);
  int offsetTableStartPos = 0;
  int offsetTableOffsetSize = 0;
  int startPos = 0;

  BinaryData({
    required this.bytes,
    required this.offsetTableStartPos,
    required this.offsetTableOffsetSize,
    required this.startPos
  });
}

class NotFoundException implements Exception {
  String message;
  NotFoundException(this.message);

  @override
  String toString() => 'NotFoundExceptions: $message';
}
