import 'package:plist_parser/plist_parser.dart';

import 'dart:io';

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

void main() async {
  // parse from xml string
  var result = PlistParser().parse(xml);
  print(result);
  print("int_type: ${result["int_type"]}");
  print("array_type[1]: ${result["array_type"][1]}\n");

  // parse from plist file
  PlistParser().parseFile("${Directory.current.path}/example/example.plist")
      .then((value) => print("parseFile\n$result\n"));

  // parse from plist file sync
  result = PlistParser().parseFileSync("${Directory.current.path}/example/example.plist");
  print("parseFileSync\n$result\n");

  // parse from binary file
  var filePath = "${Directory.current.path}/example/example_binary.plist";
  PlistParser().parseBinaryFile(filePath)
  .then((value) {
    print("parseBinaryFile\n$value\n");
  });

  // parse from binary file sync
  filePath = "${Directory.current.path}/example/example_binary.plist";
  print("parseBinaryFileSync\n${PlistParser().parseBinaryFileSync(filePath)}\n");

  // parse from binary bytes
  var file = File("${Directory.current.path}/example/example_binary.plist");
  var bytes = file.readAsBytesSync();
  print("parseBinaryBytes\n${PlistParser().parseBinaryBytes(bytes)}\n");
}
