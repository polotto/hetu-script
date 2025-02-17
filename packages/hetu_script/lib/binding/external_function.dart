import '../type/type.dart';
import '../value/function/function.dart';
import '../value/entity.dart';

/// typedef of external function for binding.
typedef HTExternalFunction = dynamic Function(
    {List<dynamic> positionalArgs,
    Map<String, dynamic> namedArgs,
    List<HTType> typeArgs});

/// typedef of external method for binding.
typedef HTExternalMethod = dynamic Function(HTEntity object,
    {List<dynamic> positionalArgs,
    Map<String, dynamic> namedArgs,
    List<HTType> typeArgs});

/// Accept a hetu function object, then return a dart function
/// for use in Dart code. This is for usage where you want to
/// write a function in script. and want to pass it to a
/// external dart function where it accepts only a pure Dart
/// native function as parameter.
typedef HTExternalFunctionTypedef = Function Function(HTFunction hetuFunction);

class DaobjectTypeReflectResult {
  final bool success;
  final String typeString;

  DaobjectTypeReflectResult(this.success, this.typeString);
}

typedef HTExternalTypeReflection = DaobjectTypeReflectResult Function(
    dynamic object);
