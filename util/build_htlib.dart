import 'dart:io';

final Map<String, String> builtInModules = const {
  'hetu:core': '../hetu_lib/hetu_lib/core/core.ht',
  'hetu:value': '../hetu_lib/core/value.ht',
  'hetu:system': '../hetu_lib/core/system.ht',
  'hetu:console': '../hetu_lib/core/console.ht',
  'hetu:math': '../hetu_lib/core/math.ht',
  'hetu:help': '../hetu_lib/core/help.ht',
};

final Map<String, String> optionalModules = const {};

void main() {
  stdout.write('Converting files in \'hetu_lib\' folder into Dart strings...');
  final output = StringBuffer();
  output.write('''
/// This file has been automatically generated 
/// from files in [hetu_lib] folder.
/// Please do not edit manually.
///
/// The pre-included modules of Hetu scripting language.
final Map<String, String> builtInModules = const {
''');
  final file = File('../packages/hetu_script/lib/buildin//hetu_lib.dart');
  for (final key in builtInModules.keys) {
    final data = File(builtInModules[key]!).readAsStringSync();
    output.writeln("  '$key': r'''" + data + "''',");
  }
  output.writeln('};');
  final content = output.toString();
  file.writeAsStringSync(content);
  stdout.writeln(' done!');
}
