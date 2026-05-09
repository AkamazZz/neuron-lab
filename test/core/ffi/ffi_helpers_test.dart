import 'dart:convert';
import 'dart:ffi';

import 'package:ccn_visualization/core/ffi/ccn_bindings.dart';
import 'package:ccn_visualization/core/ffi/ccn_status.dart';
import 'package:ccn_visualization/core/ffi/native_buffer.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes native JSON buffer', () {
    final bytes = utf8.encode('{"valid":true}');
    final pointer = calloc<Uint8>(bytes.length);
    for (var i = 0; i < bytes.length; i += 1) {
      pointer[i] = bytes[i];
    }
    final buffer = calloc<CcnBuffer>();
    buffer.ref
      ..ptr = pointer
      ..len = bytes.length
      ..cap = bytes.length;

    expect(decodeJsonObject(buffer.ref)['valid'], true);

    calloc.free(pointer);
    calloc.free(buffer);
  });

  test('maps validation status to typed exception and frees message', () {
    final bytes = utf8.encode('invalid config');
    final pointer = calloc<Uint8>(bytes.length);
    for (var i = 0; i < bytes.length; i += 1) {
      pointer[i] = bytes[i];
    }
    final status = calloc<CcnStatusStruct>();
    status.ref
      ..code = 1
      ..errorKind = CcnErrorKind.validationFailed.code
      ..message.ptr = pointer
      ..message.len = bytes.length
      ..message.cap = bytes.length;
    var freed = false;

    expect(
      () => throwIfStatusError(status.ref, (_) => freed = true),
      throwsA(
        isA<CcnNativeException>().having(
          (error) => error.kind,
          'kind',
          CcnErrorKind.validationFailed,
        ),
      ),
    );
    expect(freed, isTrue);

    calloc.free(pointer);
    calloc.free(status);
  });
}
