import 'dart:convert';
import 'dart:ffi';

import 'ccn_bindings.dart';

String decodeNativeBuffer(CcnBuffer buffer) {
  if (buffer.ptr == nullptr || buffer.len == 0) {
    return '';
  }
  return utf8.decode(buffer.ptr.asTypedList(buffer.len));
}

Map<String, Object?> decodeJsonObject(CcnBuffer buffer) {
  final text = decodeNativeBuffer(buffer);
  if (text.isEmpty) {
    return <String, Object?>{};
  }
  return (jsonDecode(text) as Map).cast<String, Object?>();
}
