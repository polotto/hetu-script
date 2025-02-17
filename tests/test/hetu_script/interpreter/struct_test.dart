import 'package:test/test.dart';
import 'package:hetu_script/hetu_script.dart';

void main() {
  final hetu = Hetu();
  hetu.init();

  group('struct -', () {
    test('basics', () {
      final result = hetu.eval(r'''
        fun structBasicTest {
          var foo = {
            value: 42,
            greeting: 'hi!'
          }
          foo.value = 'ha!'
          foo.world = 'everything'
          return foo.toString()
        }
      ''', invokeFunc: 'structBasicTest');
      expect(
        result,
        r'''{
  value: ha!,
  greeting: hi!,
  world: everything
}''',
      );
    });
  });
}
