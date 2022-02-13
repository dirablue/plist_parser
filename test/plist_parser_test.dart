import 'dart:io';
import 'dart:typed_data';

import 'package:plist_parser/plist_parser.dart';
import 'package:test/test.dart';
import 'dart:convert';

import 'package:xml/xml.dart';

void main() {
  const xml = '''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>string_type</key>
      <string>hello plist</string>
      <key>int_type</key>
      <integer>12345</integer>
      <key>double_type</key>
      <real>12.345</real>
      <key>bool_type_true</key>
      <true/>
      <key>bool_type_false</key>
      <false/>
      <key>date_type</key>
      <date>2022-02-11T18:27:45Z</date>
      <key>data_type</key>
      <data>VGVzdCBWYWx1ZQ==</data>
      <key>dict_type</key>
      <dict>
        <key>key1</key>
        <string>value1</string>
        <key>key2</key>
        <integer>2</integer>
        <key>long_key_item_name_aaaaa_bbbbb_ccccc_ddddd_eeeee</key>
        <string>long_key_item_value_11111_22222_33333_44444_55555</string>
      </dict>
      <key>array_type</key>
      <array>
        <string>array item1</string>
        <string>array item2</string>
      </array>
      <key>array_type2</key>
      <array>
        <string>array2 item1</string>
        <dict>
          <key>nest_array</key>
          <array>
            <string>nest_array_item</string>
          </array>
          <key>nest_dict</key>
          <dict>
            <key>nest_dict_item</key>
            <integer>12345</integer>
          </dict>
        </dict>
      </array>
    </dict>
    </plist>
  ''';

  group('PlistParser', () {
    group('parse', () {
      test('parse: xml text', () {
        var map = PlistParser().parse(xml);

        expect(map["string_type"], "hello plist");
        expect(map["int_type"], 12345);
        expect(map["double_type"], 12.345);
        expect(map["bool_type_true"], true);
        expect(map["bool_type_false"], false);
        expect(map["date_type"], DateTime.parse("2022-02-11T18:27:45Z"));

        // decode base64 string
        expect(map["data_type"],
            String.fromCharCodes(base64.decode("VGVzdCBWYWx1ZQ==")));

        // dictionary
        {
          var dict = map["dict_type"];
          expect(dict["key1"], "value1");
          expect(dict["key2"], 2);
          expect(dict["long_key_item_name_aaaaa_bbbbb_ccccc_ddddd_eeeee"],
              "long_key_item_value_11111_22222_33333_44444_55555");
        }

        // array
        {
          var array = map["array_type"] as List;
          expect(array.length, 2);
          if (array.length == 2) {
            expect(array[0], "array item1");
            expect(array[1], "array item2");
          }
        }

        // array2
        {
          var array2 = map["array_type2"] as List;
          if (array2.length == 2) {
            expect(array2[0], "array2 item1");

            var dict = array2[1];
            expect(dict["nest_array"], ["nest_array_item"]);

            var nestDict = dict["nest_dict"];
            expect(nestDict["nest_dict_item"], 12345);
          }
        }

        var expected = map;

        // if true, it detects xml format and use xml parser
        var map2 = PlistParser().parse(xml, typeDetection: true);
        expect(map2, expected, reason: "typeDetection: true");

        // if false, use xml parser
        var map3 = PlistParser().parse(xml, typeDetection: false);
        expect(map3, expected, reason: "typeDetection: false");
      });

      test('parse: binary file', () {
        var file = File("${Directory.current.path}/test/test_binary.plist");

        var expected = PlistParser().parse(xml);
        var map2 =
            PlistParser().parse(String.fromCharCodes(file.readAsBytesSync()));
        expect(map2, expected);

        // if typeDetection = true, use binary parser
        var map3 = PlistParser().parse(
            String.fromCharCodes(file.readAsBytesSync()),
            typeDetection: true);
        expect(map3, expected);

        // if typeDetection = false, use xml parser and it will be an error
        expect(
            () => PlistParser().parse(
                String.fromCharCodes(file.readAsBytesSync()),
                typeDetection: false),
            throwsA(isA<XmlParserException>()));
      });
    });

    group('parseBytes', () {
      test('parseBytes: xml', () {
        var bytes = Uint8List.fromList(xml.codeUnits);

        var expected = PlistParser().parse(xml);

        var map = PlistParser().parseBytes(bytes);
        expect(map, expected);

        // if true, use xml parser
        var map2 = PlistParser().parseBytes(bytes, typeDetection: true);
        expect(map2, expected, reason: "typeDetection: true");

        // if false, use xml parser
        var map3 = PlistParser().parseBytes(bytes, typeDetection: false);
        expect(map3, expected, reason: "typeDetection: false");
      });

      test('parseBytes: binary', () {
        var expected = PlistParser().parse(xml);

        var file = File("${Directory.current.path}/test/test_binary.plist");
        var bytes = file.readAsBytesSync();

        var map = PlistParser().parseBytes(bytes);
        expect(map, expected);

        // if false, use binary parser
        var map2 = PlistParser().parseBytes(bytes, typeDetection: true);
        expect(map2, expected, reason: "typeDetection: true");

        // if true, use xml parser and it will be an error
        expect(() => PlistParser().parseBytes(bytes, typeDetection: false),
            throwsA(isA<XmlParserException>()));
      });
    });

    group('parseFileSync', () {
      test('parseFileSync: xml', () {
        var expected = PlistParser().parse(xml);

        var filePath = "${Directory.current.path}/test/test.plist";

        var map = PlistParser().parseFileSync(filePath);
        expect(map, expected);

        // if true, use xml parser
        var map2 = PlistParser().parseFileSync(filePath, typeDetection: true);
        expect(map2, expected, reason: "typeDetection: true");

        // if false, use xml parser
        var map3 = PlistParser().parseFileSync(filePath, typeDetection: false);
        expect(map3, expected, reason: "typeDetection: false");

        // not found file
        expect(() => PlistParser().parseFileSync("dummy/dummy.plist"),
            throwsA(isA<NotFoundException>()));
      });

      test('parseFileSync: binary', () {
        var expected = PlistParser().parse(xml);

        var filePath = "${Directory.current.path}/test/test_binary.plist";

        var map = PlistParser().parseFileSync(filePath);
        expect(map, expected);

        // if false, use binary parser
        var map2 = PlistParser().parseFileSync(filePath, typeDetection: true);
        expect(map2, expected, reason: "typeDetection: true");

        // if true, use xml parser and it will be an error
        expect(
            () => PlistParser().parseFileSync(filePath, typeDetection: false),
            throwsA(isA<XmlParserException>()));
      });
    });

    group('parseFile', () {
      test('parseFile: xml', () async {
        var expected = PlistParser().parse(xml);

        var filePath = "${Directory.current.path}/test/test.plist";

        var map = await PlistParser().parseFile(filePath);
        expect(map, expected);

        // if true, use xml parser
        var map2 = await PlistParser().parseFile(filePath, typeDetection: true);
        expect(map2, expected, reason: "typeDetection: true");

        // if false, use xml parser
        var map3 =
            await PlistParser().parseFile(filePath, typeDetection: false);
        expect(map3, expected, reason: "typeDetection: false");

        // not found file
        expect(await () => PlistParser().parseFile("dummy/dummy.plist"),
            throwsA(isA<NotFoundException>()));
      });

      test('parseFile: binary', () async {
        var expected = PlistParser().parse(xml);

        var filePath = "${Directory.current.path}/test/test_binary.plist";

        var map = await PlistParser().parseFile(filePath);
        expect(map, expected);

        // if false, use binary parser
        var map2 = await PlistParser().parseFile(filePath, typeDetection: true);
        expect(map2, expected, reason: "typeDetection: true");

        // if true, use xml parser and it will be an error
        expect(
            await () => PlistParser().parseFile(filePath, typeDetection: false),
            throwsA(isA<XmlParserException>()));
      });
    });

    test('isBinaryTypeText', () async {
      // xml
      expect(PlistParser().isBinaryTypeText(xml), false);

      // binary
      var file = File("${Directory.current.path}/test/test_binary.plist");
      var binaryString =
          String.fromCharCodes(Uint8List.fromList(file.readAsBytesSync()));
      expect(PlistParser().isBinaryTypeText(binaryString), true);
    });

    test('isBinaryTypeBytes', () async {
      // xml
      var xmlBytes = Uint8List.fromList(xml.codeUnits);
      expect(PlistParser().isBinaryTypeBytes(xmlBytes), false);

      // binary
      var file = File("${Directory.current.path}/test/test_binary.plist");
      var binaryBytes = Uint8List.fromList(file.readAsBytesSync());
      expect(PlistParser().isBinaryTypeBytes(binaryBytes), true);
    });

    test('parseXml', () async {
      var expected = PlistParser().parse(xml);
      expect(PlistParser().parseXml(xml), expected);

      // no xml elements
      expect(await () => PlistParser().parseXml("<div></div>"),
          throwsA(isA<NotFoundException>()));
    });

    test('parseXmlFileSync', () {
      var expected = PlistParser().parse(xml);

      var filePath = "${Directory.current.path}/test/test.plist";
      expect(PlistParser().parseXmlFileSync(filePath), expected);

      // no xml elements
      expect(() => PlistParser().parseXmlFileSync("<div></div>"),
      throwsA(isA<NotFoundException>()));
    });

    test('parseXmlFile', () async {
      var expected = PlistParser().parse(xml);

      var filePath = "${Directory.current.path}/test/test.plist";
      expect(await PlistParser().parseXmlFile(filePath), expected);

      // no xml elements
      expect(await () => PlistParser().parseXmlFile("dummy/dummy.plist"),
          throwsA(isA<NotFoundException>()));
    });

    test('parseBinaryFileSync', () {
      var expected = PlistParser().parse(xml);

      var filePath = "${Directory.current.path}/test/test_binary.plist";
      expect(PlistParser().parseBinaryFileSync(filePath), expected);

      // not found file
      expect(() => PlistParser().parseBinaryFileSync("dummy/dummy.plist"),
        throwsA(isA<NotFoundException>()));
    });

    test('parseBinaryFile', () async {
      var expected = PlistParser().parse(xml);

      var filePath = "${Directory.current.path}/test/test_binary.plist";
      expect(await PlistParser().parseBinaryFile(filePath), expected);

      // not found file
      expect(await () => PlistParser().parseBinaryFile("dummy/dummy.plist"),
          throwsA(isA<NotFoundException>()));
    });

    test('parseBinaryBytes', () async {
      var expected = PlistParser().parse(xml);

      var file = File("${Directory.current.path}/test/test_binary.plist");
      expect(await PlistParser().parseBinaryBytes(file.readAsBytesSync()),
          expected);
    });

    test('bytesToInt', () async {
      var list = [1, 2, 3, 4];
      var expected = ByteData.view(Uint8List.fromList(
          list).buffer).getInt8(0);
      expect(PlistParser().bytesToInt(list, 1), expected);

      list = [1, 2, 3, 4, 5, 6, 7, 8];
      expected = ByteData.view(Uint8List.fromList(
          list).buffer).getInt16(0);
      expect(PlistParser().bytesToInt(list, 2), expected);

      list = [
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 10, 11, 12,
        13, 14, 15, 16
      ];
      expected = ByteData.view(Uint8List.fromList(
          list).buffer).getInt32(0);
      expect(PlistParser().bytesToInt(list, 4), expected);

      list = [
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 10, 11, 12,
        13, 14, 15, 16,
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 10, 11, 12,
        13, 14, 15, 16,
      ];
      expected = ByteData.view(Uint8List.fromList(
          list).buffer).getInt64(0);
      expect(PlistParser().bytesToInt(list, 8), expected);

      // if list is empty, it will be an error
      list = [];
      expect(
          () => PlistParser().bytesToInt(list, 1),
          throwsA(isA<Exception>()));

      // if specified bytes is undefined, it will be an error
      list = [1, 2, 3, 4];
      expect(
              () => PlistParser().bytesToInt(list, 7),
          throwsA(isA<Exception>()));
    });

    test('bytesToDouble', () async {
      var list = [
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
      ];
      var expected = ByteData.view(Uint8List.fromList(
          list).buffer).getFloat32(0);
      expect(PlistParser().bytesToDouble(list, 4), expected);

      list = [
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,

        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
        1, 2, 3, 4, 5, 6, 7, 8,
      ];
      expected = ByteData.view(Uint8List.fromList(
          list).buffer).getFloat64(0);
      expect(PlistParser().bytesToDouble(list, 8), expected);

      // if list is empty, it will be an error
      list = [];
      expect(
              () => PlistParser().bytesToDouble(list, 4),
          throwsA(isA<Exception>()));

      // if specified bytes is undefined, it will be an error
      list = [1];
      expect(
              () => PlistParser().bytesToDouble(list, 1),
          throwsA(isA<Exception>()));
    });

    test('NotFoundException', () {
      expect(NotFoundException("test12345").toString(), matcherContainsString("test12345"));
    });
  });
}

Matcher matcherContainsString(String substring) =>
    predicate((String expected) => expected.contains(RegExp(substring, caseSensitive: false)));

