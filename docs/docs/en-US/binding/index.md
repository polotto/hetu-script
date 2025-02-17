# Binding

## Function

### Typedef of external function

External functions (for both global and methods) can be binded as the following type:

```dart
typedef HTExternalFunction = dynamic Function(
    {List<dynamic> positionalArgs, Map<String, dynamic> namedArgs, List<HTTypeId> typeArgs});

await hetu.init(externalFunctions: {
  // you can omit the type, and keep the correct type parameter names,
  // this way Dart will still count it as HTExternalFunction
  'hello': ({positionalArgs, namedArgs, typeArgs}) => {'greeting': 'hello'},
});
```

or even you can directy write it as a Dart Function:

```dart
await hetu.init(externalFunctions: {
  'hello': () => {'greeting': 'hello'},
});
```

It's easier to write and read in Dart Function form. However, this way the Interpreter will have to use Dart's [Function.apply] feature to call it. This is normally slower and inefficient than direct call.

## Binding external function

To call Dart functions in Hetu, just init Hetu with [externalFunctions].

Then define those dart funtion in Hetu with [external] keyword.

Then you can call those functions in Hetu.

You can pass object from Dart to Hetu by the return value of external functions.

You can pass object from Hetu to Dart by the return value of Interpreter's [invoke] function;

```typescript
import 'package:hetu_script/hetu_script.dart';

void main() async {
  var hetu = Hetu();
  await hetu.init(externalFunctions: {
    'hello': (
        {List<dynamic> positionalArgs = const [],
            Map<String, dynamic> namedArgs = const {},
            List<HTTypeId> typeArgs = const []}) => {'greeting': 'hello'},
  });
  await hetu.eval(r'''
      external fun hello
      fun main {
        var dartValue = hello()
        print('dart value:', dartValue)
        dartValue['foo'] = 'bar'
        return dartValue
      }''');

  var hetuValue = hetu.invoke('main');

  print('hetu value: $hetuValue');
}
```

And the output should be:

```
dart value: {greeting: hello}
hetu value: {greeting: hello, foo: bar}
```

## Typedef for unwrap Hetu function into Dart function

In Hetu script:

```dart
fun [DartFunction] add(a: num, b: num) -> num {
  return a + b
}

fun getFunc {
  return add
}
```

Then when you evaluate this [add] function in Hetu, you will get a native Dart function.
This grammar could also be used on literal function, this is especially usefull when you try to bind callback function to a dart widget.

```dart
typedef DartFunction = int Function(int a, int b);

int hetuAdd(DartFunction func) {
  var func = hetu.invoke('getFunc');
  return func(6, 7);
}
```

You have to bind the Dart typedef in [Interpreter.init] before you can use it.

```dart
await hetu.init(externalFunctions: {
  externalFunctionTypedef: {
  'DartFunction': (HTFunction function) {
    return (int a, int b) {
      // must convert the return type here to let dart know its return value type.
      return function.call([a, b]) as int;
    };
  },
});
```

The typedef of the unwrapper is:

```dart
typedef HTExternalFunctionTypedef = Function Function(HTFunction hetuFunction);
```

## Binding of External class

It's possible to get and return pure Dart object with class information in Hetu.

To achieve this, you have to write a full definition of that class in Hetu, which includes 4 parts of code:

- Original class definition of the class you intended to use in Hetu. For Dart & Flutter, this is the part where you already have when you import a library.
- An extension on that class. This part is used for dynamic reflection in Hetu and should return members of this class.
- A binding definition of that class, which extends [HTExternalClass] interface provided by Hetu's dart lib. This part is used for access to the constructor and static members of that class.
- A Hetu version of class definition of that class. This part is used for Hetu to understand the structure and type of this class.

You can check the following example for how to bind a class and its various kinds of members.

```dart
import 'package:hetu_script/hetu_script.dart';

class Person {
  static final races = <String>['Caucasian'];
  static String _level = '0';
  static String get level => _level;
  static set level(value) => _level = value;
  static String meaning(int n) => 'The meaning of life is $n';

  String get child => 'Tom';

  String name;
  String race;

  Person([this.name = 'Jimmy', this.race = 'Caucasian']);

  Person.withName(this.name, [this.race = 'Caucasian']);

  void greeting(String tag) {
    print('Hi! $tag');
  }
}

extension PersonBinding on Person {
  dynamic htFetch(String varName) {
    switch (varName) {
      case 'name':
        return name;
      case 'race':
        return race;
      case 'greeting':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {},
                List<HTType> typeArgs = const []}) =>
            greeting(positionalArgs.first);
      case 'child':
        return child;
      default:
        throw HTError.undefined(varName);
    }
  }

  void htAssign(String varName, dynamic varValue) {
    switch (varName) {
      case 'name':
        name = varValue;
        break;
      case 'race':
        race = varValue;
        break;
      default:
        throw HTError.undefined(varName);
    }
  }
}

class PersonClassBinding extends HTExternalClass {
  PersonClassBinding() : super('Person');

  @override
  dynamic memberGet(String varName) {
    switch (varName) {
      case 'Person':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {},
                List<HTType> typeArgs = const []}) =>
            Person(positionalArgs[0], positionalArgs[1]);
      case 'Person.withName':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {},
                List<HTType> typeArgs = const []}) =>
            Person.withName(positionalArgs[0],
                (positionalArgs.length > 1 ? positionalArgs[1] : 'Caucasion'));
      case 'Person.meaning':
        return (
                {List<dynamic> positionalArgs = const [],
                Map<String, dynamic> namedArgs = const {},
                List<HTType> typeArgs = const []}) =>
            Person.meaning(positionalArgs[0]);
      case 'Person.level':
        return Person.level;
      default:
        throw HTError.undefined(varName);
    }
  }

  @override
  void memberSet(String varName, dynamic varValue) {
    switch (varName) {
      case 'Person.race':
        throw HTError.immutable(varName);
      case 'Person.level':
        return Person.level = varValue;
      default:
        throw HTError.undefined(varName);
    }
  }

  @override
  dynamic instanceMemberGet(dynamic object, String varName) {
    var i = object as Person;
    return i.htFetch(varName);
  }

  @override
  void instanceMemberSet(dynamic object, String varName, dynamic varValue) {
    var i = object as Person;
    i.htAssign(varName, varValue);
  }
}

void main() {
  var hetu = Hetu();
  hetu.init(externalClasses: [PersonClassBinding()]);
  hetu.eval('''
      external class Person {
        var race: str
        construct([name: str = 'Jimmy', race: str = 'Caucasian']);
        get child
        static fun meaning(n: num)
        static get level
        static set level (value: str)
        construct withName(name: str, [race: str = 'Caucasian'])
        var name
        fun greeting(tag: str)
      }
      fun main {
        var p1: Person = Person()
        p1.greeting('jimmy')
        print(typeof p1)
        print(p1.name)
        print(p1.child)
        print('My race is', p1.race)
        p1.race = 'Reptile'
        print('Oh no! My race turned into', p1.race)

        var p2 = Person.withName('Jimmy')
        print(p2.name)
        p2.name = 'John'

        Person.level = '3'
        print(Person.level)

        print(Person.meaning(42))
      }
      ''', invokeFunc: 'main');
}
```

## Auto-Binding tools

Thanks to [rockingdice](https://github.com/rockingdice) we now have an automated tool for auto-generate both Dart-side and Hetu-side binding declarations for any Dart classes.

Please check out this repository: [hetu-script-autobinding](https://github.com/hetu-script/hetu-script-autobinding)
