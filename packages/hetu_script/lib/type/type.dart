import 'package:quiver/core.dart';

import '../grammar/lexicon.dart';
import '../value/entity.dart';
import '../declaration/namespace/namespace.dart';
import 'unresolved_type.dart';
import '../ast/ast.dart' show TypeExpr, FuncTypeExpr;
import 'function_type.dart';
import '../declaration/generic/generic_type_parameter.dart';

abstract class HTType with HTEntity {
  static const ANY = _PrimitiveType(HTLexicon.ANY);
  static const NULL = _PrimitiveType(HTLexicon.NULL);
  static const VOID = _PrimitiveType(HTLexicon.VOID);
  static const ENUM = _PrimitiveType(HTLexicon.ENUM);
  static const NAMESPACE = _PrimitiveType(HTLexicon.NAMESPACE);
  static const CLASS = _PrimitiveType(HTLexicon.CLASS);
  static const UNKNOWN = _PrimitiveType(HTLexicon.UNKNOWN);
  // static const object = _PrimitiveType(HTLexicon.object);
  static const function = _PrimitiveType(HTLexicon.FUNCTION);
  static const type = _PrimitiveType(HTLexicon.type);

  static const Map<String, HTType> primitiveTypes = {
    HTLexicon.type: type,
    HTLexicon.ANY: ANY,
    HTLexicon.NULL: NULL,
    HTLexicon.VOID: VOID,
    // HTLexicon.ENUM: ENUM,
    // HTLexicon.NAMESPACE: NAMESPACE,
    // HTLexicon.CLASS: CLASS,
    HTLexicon.UNKNOWN: UNKNOWN,
    // HTLexicon.object: object,
    // HTLexicon.FUNCTION: function,
  };

  static String parseBaseType(String typeString) {
    final argsStart = typeString.indexOf(HTLexicon.typesBracketLeft);
    if (argsStart != -1) {
      final id = typeString.substring(0, argsStart);
      return id;
    } else {
      return typeString;
    }
  }

  bool get isResolved => true;

  HTType resolve(HTNamespace namespace) => this;

  @override
  HTType get valueType => HTType.type;

  final String id;
  final List<HTType> typeArgs;
  final bool isNullable;

  const HTType(this.id, {this.typeArgs = const [], this.isNullable = false});

  factory HTType.fromAst(TypeExpr? ast) {
    if (ast != null) {
      if (ast is FuncTypeExpr) {
        return HTFunctionType(
            genericTypeParameters: ast.genericTypeParameters
                .map((param) => HTGenericTypeParameter(param.id.id,
                    superType: HTType.fromAst(param.superType)))
                .toList(),
            parameterTypes: ast.paramTypes
                .map((param) => HTParameterType(HTType.fromAst(param.declType),
                    isOptional: param.isOptional,
                    isVariadic: param.isVariadic,
                    id: param.id?.id))
                .toList(),
            returnType: HTType.fromAst(ast.returnType));
      } else {
        if (HTType.primitiveTypes.containsKey(ast.id)) {
          return HTType.primitiveTypes[ast.id]!;
        } else {
          return HTUnresolvedType(ast.id.id,
              typeArgs:
                  ast.arguments.map((expr) => HTType.fromAst(expr)).toList(),
              isNullable: ast.isNullable);
        }
      }
    } else {
      return HTType.ANY;
    }
  }

  @override
  int get hashCode {
    final hashList = <int>[];
    hashList.add(id.hashCode);
    hashList.add(isNullable.hashCode);
    for (final typeArg in typeArgs) {
      hashList.add(typeArg.hashCode);
    }
    final hash = hashObjects(hashList);
    return hash;
  }

  @override
  bool operator ==(Object other) => hashCode == other.hashCode;

  @override
  String toString() {
    var typeString = StringBuffer();
    typeString.write(id);
    if (typeArgs.isNotEmpty) {
      typeString.write(HTLexicon.angleLeft);
      for (var i = 0; i < typeArgs.length; ++i) {
        typeString.write(typeArgs[i]);
        if ((typeArgs.length > 1) && (i != typeArgs.length - 1)) {
          typeString.write('${HTLexicon.comma} ');
        }
      }
      typeString.write(HTLexicon.angleRight);
    }
    if (isNullable) {
      typeString.write(HTLexicon.nullable);
    }
    return typeString.toString();
  }

  /// Wether object of this [HTType] can be assigned to other [HTType]
  bool isA(HTType? other) {
    if (other == null) {
      return true;
    } else if (this == HTType.UNKNOWN) {
      if (other == HTType.ANY || other == HTType.UNKNOWN) {
        return true;
      } else {
        return false;
      }
    } else if (other == HTType.ANY) {
      return true;
    } else {
      if (this == HTType.NULL) {
        // TODO: 这里是 nullable 功能的开关
        // if (other.isNullable) {
        //   return true;
        // } else {
        //   return false;
        // }
        return true;
      } else if (id != other.id) {
        return false;
      }
      // else if (typeArgs.length != other.typeArgs.length) {
      //   return false;
      // }
      else {
        // for (var i = 0; i < typeArgs.length; ++i) {
        //   if (!typeArgs[i].isA(typeArgs[i])) {
        //     return false;
        //   }
        // }
        return true;
      }
    }
  }

  /// Wether object of this [HTType] cannot be assigned to other [HTType]
  bool isNotA(HTType? other) => !isA(other);
}

class _PrimitiveType extends HTType {
  const _PrimitiveType(String id) : super(id);
}
