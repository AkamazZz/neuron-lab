import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await const RustBuilder(
      assetName: 'core/ffi/ccn_bindings.dart',
      cratePath: 'rust',
      buildMode: BuildMode.release,
    ).run(input: input, output: output);
  });
}
