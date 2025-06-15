# 📋 Plist Parser for Flutter

[![pub package](https://img.shields.io/pub/v/plist_parser.svg)](https://pub.dartlang.org/packages/plist_parser)
[![codecov](https://codecov.io/gh/dirablue/plist_parser/branch/master/graph/badge.svg?token=TI85EVM71J)](https://codecov.io/gh/dirablue/plist_parser)

A Flutter Plugin for Plist parser supporting XML and Binary formats.

The parser is designed to read XML and Binary of plist format on Dart and Flutter.

This was inspired by some libraries. please see below details.

## 🔧 Installation

```yaml
dependencies:
  plist_parser: "^0.2.2"
```

## 📋 Requirements

Dart SDK

```
environment:
  sdk: ">=2.16.0 <4.0.0"
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
  // Parse from xml string.
  //
  // Parse method detects the plist format automatically and use xml or binary parser.
  // Default parameter: typeDetection = true.
  // To disable the detection, use typeDetection = false then it will use xml parser.
  var result = PlistParser().parse(xml);
  print(result);

  // Parse from xml file.
  //
  // You can use "parseFile"(for Async) or "parseFileSync".
  var result2 = PlistParser().parseFileSync("${Directory.current.path}/example/plist_xml.plist");
  print(result2);

  // Parse from binary file.
  //
  // It detects binary format and use binary parser automatically.
  var result3 = PlistParser().parseFileSync(
      "${Directory.current.path}/example/plist_binary.plist");
  print(result3);
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
    dict_type: {key1: value1, key2: 2}, 
    array_type: [array item1, array item2]
}
{string_type: hello plist, int_type: 12345, double_type: 12.345, bool_type_true: true, bool_type_false: false, date_type: 2022-02-11 18:27:45.000Z, data_type: Test Value, dict_type: {key1: value1, key2: 2, long_key_item_name_aaaaa_bbbbb_ccccc_ddddd_eeeee: long_key_item_value_11111_22222_33333_44444_55555}, array_type: [array item1, array item2], array_type2: [array2 item1, {nest_array: [nest_array_item], nest_dict: {nest_dict_item: 12345}}]}
{array_type2: [array2 item1, {nest_dict: {nest_dict_item: 12345}, nest_array: [nest_array_item]}], date_type: 2022-02-11 18:27:45.000Z, double_type: 12.345, string_type: hello plist, bool_type_true: true, array_type: [array item1, array item2], bool_type_false: false, dict_type: {key1: value1, key2: 2, long_key_item_name_aaaaa_bbbbb_ccccc_ddddd_eeeee: long_key_item_value_11111_22222_33333_44444_55555}, data_type: Test Value, int_type: 12345}
```

Other examples are stored in /example/plist_parser_example.dart

## ✨ Inspiration

* https://github.com/gjersvik/plist
* https://github.com/animetrics/PlistCpp

## 💡 References

* https://medium.com/@karaiskc/understanding-apples-binary-property-list-format-281e6da00dbd
