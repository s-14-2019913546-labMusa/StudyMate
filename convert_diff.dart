import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  var bytes = File('diff.txt').readAsBytesSync();
  // Decode UTF-16LE
  var result = '';
  for (var i = 0; i < bytes.length; i += 2) {
    if (i + 1 < bytes.length) {
      int charCode = bytes[i] | (bytes[i + 1] << 8);
      result += String.fromCharCode(charCode);
    }
  }
  File('diff_clean.txt').writeAsStringSync(result);
  print('Converted to diff_clean.txt');
}
