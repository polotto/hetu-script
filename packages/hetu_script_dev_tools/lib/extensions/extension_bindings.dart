import 'dart:io';

import 'package:hetu_script/hetu_script.dart';

class HTConsoleClass extends HTExternalClass {
  HTConsoleClass() : super('Console');

  @override
  dynamic memberGet(String varName) {
    switch (varName) {
      case 'Console.write':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {},
                List<HTType> typeArgs = const []}) =>
            stdout.write(positionalArgs.first);
      case 'Console.writeln':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {},
                List<HTType> typeArgs = const []}) =>
            stdout.writeln(positionalArgs.first);
      case 'Console.getln':
        return (
            {List<dynamic> positionalArgs = const [],
            Map<String, dynamic> namedArgs = const {},
            List<HTType> typeArgs = const []}) {
          if (positionalArgs.isNotEmpty) {
            stdout.write('${positionalArgs.first}');
          } else {
            stdout.write('>');
          }
          return stdin.readLineSync();
        };
      case 'Console.eraseLine':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {},
                List<HTType> typeArgs = const []}) =>
            stdout.write('\x1B[1F\x1B[1G\x1B[1K');
      case 'Console.setTitle':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {},
                List<HTType> typeArgs = const []}) =>
            stdout.write('\x1b]0;${positionalArgs.first}\x07');
      case 'Console.clear':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {},
                List<HTType> typeArgs = const []}) =>
            stdout.write('\x1B[2J\x1B[0;0H');
      default:
        throw HTError.undefined(varName);
    }
  }
}
