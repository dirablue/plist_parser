# 📋 Plist Parser for Flutter
 
[![pub package](https://img.shields.io/pub/v/plist_parser.svg)](https://pub.dartlang.org/packages/plist_parser)
[![codecov](https://codecov.io/gh/dirablue/plist_parser/branch/master/graph/badge.svg?token=TI85EVM71J)](https://codecov.io/gh/dirablue/plist_parser)

A Flutter Plugin for Plist parser supporting XML and Binary formats.

It's written xml and binary parser from scratch for Dart and this is not dependent other native libraries.

This was inspired by some libraries. please see below details.     

## 🔧 Installation 

```yaml
dependencies:
  plist_parser: "^0.0.1"
```

## 🐕 Usage

```dart

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

void main() {
  // parse from xml string
  //
  // parse method detects plist format and use xml or binary parser
  // default is typeDetection = true
  // to disable the detection, use typeDetection = false
  var result = PlistParser().parse(xml);
  print(result);
  print("int_type: ${result["int_type"]}");
  print("array_type[1]: ${result["array_type"][1]}\n");

  // parse from binary file sync
  filePath = "${Directory.current.path}/example/example_binary.plist";
  print("parseBinaryFileSync\n${PlistParser().parseBinaryFileSync(filePath)}\n");
  
  // parse from binary file with auto type detection
  // you can use typeDetection = false to disable the detection
  var file = File(filePath);
  var binaryText = String.fromCharCodes(file.readAsBytesSync());
  print("parse for binary data\n${PlistParser().parse(binaryText)}\n");
}
```

The output are these:
```
// ※ Formatted for readability
{
    string_type: hello plist, 
    int_type: 12345, 
    double_type: 12.345, 
    bool_type_true: true, 
    bool_type_false: false, 
    date_type: 2022-02-11 18:27:45.000Z, 
    data_type: Test Value, 
    dict_type: {
        key1: value1, 
        key2: 2, 
        long_key_item_name_aaaaa_bbbbb_ccccc_ddddd_eeeee: long_key_item_value_11111_22222_33333_44444_55555
    }, 
    array_type: [
        array item1, 
        array item2
    ], 
    array_type2: [
        array2 item1, 
        {
            nest_array: [nest_array_item], 
            nest_dict: {
                nest_dict_item: 12345
            }
        }
    ]
}

int_type: 12345
array_type item2: array item2

parseBinaryFileSync
{array_type2: [array2 item1, {nest_dict: {nest_dict_item: 12345}, nest_array: [nest_array_item]}], date_type: 2022-02-11 18:27:45.000Z, double_type: 12.345, string_type: hello plist, bool_type_true: false, array_type: [array item1, array item2], bool_type_false: true, dict_type: {key1: value1, key2: 2, long_key_item_name_aaaaa_bbbbb_ccccc_ddddd_eeeee: long_key_item_value_11111_22222_33333_44444_55555}, data_type: Test Value, int_type: 12345}

parseBinaryFile
{array_type2: [array2 item1, {nest_dict: {nest_dict_item: 12345}, nest_array: [nest_array_item]}], date_type: 2022-02-11 18:27:45.000Z, double_type: 12.345, string_type: hello plist, bool_type_true: true, array_type: [array item1, array item2], bool_type_false: false, dict_type: {key1: value1, key2: 2, long_key_item_name_aaaaa_bbbbb_ccccc_ddddd_eeeee: long_key_item_value_11111_22222_33333_44444_55555}, data_type: Test Value, int_type: 12345}
```

Other examples are stored in /example/plist_parser_example.dart

## ✨ Inspiration 

* https://github.com/gjersvik/plist
* https://github.com/animetrics/PlistCpp

## 💡 References

* https://medium.com/@karaiskc/understanding-apples-binary-property-list-format-281e6da00dbd
