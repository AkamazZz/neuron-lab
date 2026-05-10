import 'dart:convert';
import 'dart:ffi';

import 'package:ccn_visualization/core/ffi/ccn_bindings.dart';

enum CcnErrorKind {
  unknown(0),
  invalidHandle(1),
  validationFailed(2),
  invalidArgument(3),
  internalError(4);

  const CcnErrorKind(this.code);

  final int code;

  static CcnErrorKind fromCode(int code) {
    return CcnErrorKind.values.firstWhere(
      (kind) => kind.code == code,
      orElse: () => CcnErrorKind.unknown,
    );
  }
}

class CcnNativeException implements Exception {
  const CcnNativeException({
    required this.kind,
    required this.message,
    required this.code,
  });

  final CcnErrorKind kind;
  final String message;
  final int code;

  @override
  String toString() => 'CcnNativeException($kind): $message';
}

String decodeStatusMessage(CcnStatusStruct status) {
  final message = status.message;
  if (message.ptr == nullptr || message.len == 0) {
    return '';
  }
  return utf8.decode(message.ptr.asTypedList(message.len));
}

void throwIfStatusError(
  CcnStatusStruct status,
  void Function(CcnBuffer buffer) freeBuffer,
) {
  if (status.code == 0) {
    return;
  }
  final message = decodeStatusMessage(status);
  if (status.message.ptr != nullptr) {
    freeBuffer(status.message);
  }
  throw CcnNativeException(
    kind: CcnErrorKind.fromCode(status.errorKind),
    message: message.isEmpty ? 'native call failed' : message,
    code: status.code,
  );
}
