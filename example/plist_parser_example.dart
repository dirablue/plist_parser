import 'dart:io';

import 'package:plist_parser/plist_parser.dart';

// ignore_for_file: avoid_print

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
  </dict>
  <key>array_type</key>
  <array>
    <string>array item1</string>
    <string>array item2</string>
  </array>
</dict>
</plist>
''';

void main() async {
  // parse from xml string.
  //
  // parse method detects the plist format automatically and use xml or
  // binary parser.
  // default parameter: typeDetection = true
  // to disable the detection, use typeDetection = false
  // then it will use xml parser.
  var result = PlistParser().parse(xml);
  print(result);

  // parse from xml file
  // you can use "parseFile" or "parseFileSync"
  var result2 = PlistParser()
      .parseFileSync("${Directory.current.path}/example/example.plist");
  print(result2);

  // parse from binary file
  // it detects binary format automatically
  var result3 = PlistParser()
      .parseFileSync("${Directory.current.path}/example/example_binary.plist");
  print(result3);
}
