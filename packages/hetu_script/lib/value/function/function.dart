import '../../binding/external_function.dart';
import '../../error/error.dart';
import '../../grammar/semantic.dart';
import '../../grammar/lexicon.dart';
import '../../source/source.dart';
import '../../interpreter/interpreter.dart';
import '../../interpreter/compiler.dart' show GotoInfo;
import '../../type/type.dart';
import '../../value/instance/instance_namespace.dart';
import '../../value/class/class.dart';
import '../../value/instance/instance.dart';
import '../../declaration/namespace/namespace.dart';
import 'parameter.dart';
import '../../declaration/function/function_declaration.dart';
import '../../declaration/generic/generic_type_parameter.dart';
import '../entity.dart';
import '../const.dart';

class RedirectingConstructor {
  /// id of super class's constructor
  // final String callee;
  final String name;

  final String? key;

  /// Holds ips of super class's constructor's positional argumnets
  final List<int> positionalArgsIp;

  /// Holds ips of super class's constructor's named argumnets
  final Map<String, int> namedArgsIp;

  RedirectingConstructor(this.name,
      {this.key,
      this.positionalArgsIp = const [],
      this.namedArgsIp = const {}});
}

/// Bytecode implementation of [TypedFunctionDeclaration].
class HTFunction extends HTFunctionDeclaration
    with HTEntity, HetuRef, GotoInfo {
  HTClass? klass;

  @override
  final Map<String, HTParameter> paramDecls;

  final RedirectingConstructor? redirectingConstructor;

  Function? externalFunc;

  @override
  HTType get valueType => declType;

  /// Create a standard [HTFunction].
  ///
  /// A [TypedFunctionDeclaration] has to be defined in a [HTNamespace] of an [Interpreter]
  /// before it can be called within a script.
  HTFunction(String internalName, String moduleFullName, String libraryName,
      Hetu interpreter,
      {String? id,
      String? classId,
      HTNamespace? closure,
      HTSource? source,
      bool isExternal = false,
      bool isStatic = false,
      bool isConst = false,
      bool isTopLevel = false,
      bool isExported = false,
      FunctionCategory category = FunctionCategory.normal,
      String? externalTypeId,
      List<HTGenericTypeParameter> genericTypeParameters = const [],
      bool hasParamDecls = true,
      this.paramDecls = const {},
      HTType? returnType,
      bool isAbstract = false,
      bool isVariadic = false,
      int minArity = 0,
      int maxArity = 0,
      this.externalFunc,
      int? definitionIp,
      int? definitionLine,
      int? definitionColumn,
      HTNamespace? namespace,
      this.redirectingConstructor,
      this.klass})
      : super(internalName,
            id: id,
            classId: classId,
            closure: closure,
            source: source,
            isExternal: isExternal,
            isStatic: isStatic,
            isConst: isConst,
            isTopLevel: isTopLevel,
            isExported: isExported,
            category: category,
            externalTypeId: externalTypeId,
            genericTypeParameters: genericTypeParameters,
            hasParamDecls: hasParamDecls,
            paramDecls: paramDecls,
            returnType: returnType,
            isAbstract: isAbstract,
            isVariadic: isVariadic,
            minArity: minArity,
            maxArity: maxArity,
            namespace: namespace) {
    this.interpreter = interpreter;
    this.moduleFullName = moduleFullName;
    this.libraryName = libraryName;
    this.definitionIp = definitionIp;
    this.definitionLine = definitionLine;
    this.definitionColumn = definitionColumn;
  }

  @override
  dynamic get value {
    if (externalTypeId != null) {
      final externalFunc = interpreter.unwrapExternalFunctionType(this);
      return externalFunc;
    } else {
      return this;
    }
  }

  @override
  void resolve() {
    super.resolve();

    if ((closure != null) && (classId != null) && (klass == null)) {
      klass = closure!.memberGet(classId!);
    }
  }

  @override
  HTFunction clone() =>
      HTFunction(internalName, moduleFullName, libraryName, interpreter,
          id: id,
          classId: classId,
          closure: closure,
          source: source,
          isExternal: isExternal,
          isStatic: isStatic,
          isConst: isConst,
          isTopLevel: isTopLevel,
          isExported: isExported,
          category: category,
          externalTypeId: externalTypeId,
          genericTypeParameters: genericTypeParameters,
          hasParamDecls: hasParamDecls,
          paramDecls: paramDecls,
          returnType: returnType,
          isAbstract: isAbstract,
          isVariadic: isVariadic,
          minArity: minArity,
          maxArity: maxArity,
          externalFunc: externalFunc,
          definitionIp: definitionIp,
          definitionLine: definitionLine,
          definitionColumn: definitionColumn,
          namespace: namespace,
          redirectingConstructor: redirectingConstructor,
          klass: klass);

  /// Call this function with specific arguments.
  /// ```
  /// function<typeArg1, typeArg2>(posArg1, posArg2, name1: namedArg1, name2: namedArg2)
  /// ```
  /// for variadic arguments, will transform all remaining positional arguments
  /// into a positional argument with the variadic argument's name.
  /// variadic declaration:
  /// ```
  /// fun function(... args)
  /// ```
  /// variadic calling:
  /// ```
  /// function(posArg1, posArg2...)
  /// ```
  /// ```
  /// args = [posArg1, posArg2...];
  /// ```
  dynamic call(
      {List<dynamic> positionalArgs = const [],
      Map<String, dynamic> namedArgs = const {},
      List<HTType> typeArgs = const [],
      bool createInstance = true,
      bool errorHandled = true}) {
    try {
      interpreter.stackTrace.add(
          '$internalName ($moduleFullName:${interpreter.curLine}:${interpreter.curColumn})');

      dynamic result;
      // 如果是脚本函数
      if (!isExternal) {
        if (hasParamDecls) {
          if (positionalArgs.length < minArity ||
              (positionalArgs.length > maxArity && !isVariadic)) {
            throw HTError.arity(internalName, positionalArgs.length, minArity,
                moduleFullName: interpreter.curModuleFullName,
                line: interpreter.curLine,
                column: interpreter.curColumn);
          }

          for (final name in namedArgs.keys) {
            if (!paramDecls.containsKey(name)) {
              throw HTError.namedArg(name,
                  moduleFullName: interpreter.curModuleFullName,
                  line: interpreter.curLine,
                  column: interpreter.curColumn);
            }
          }
        }

        if (category == FunctionCategory.constructor && createInstance) {
          result = HTInstance(klass!, interpreter, typeArgs: typeArgs);
          namespace = result.namespace;
        }

        if (definitionIp == null) {
          return result;
        }
        // 函数每次在调用时，临时生成一个新的作用域
        final callClosure = HTNamespace(id: id, closure: namespace);
        if (namespace is HTInstanceNamespace) {
          final instanceNamespace = namespace as HTInstanceNamespace;
          if (instanceNamespace.next != null) {
            callClosure.define(HTLexicon.SUPER,
                HTConst(HTLexicon.SUPER, value: instanceNamespace.next));
          }

          callClosure.define(HTLexicon.THIS,
              HTConst(HTLexicon.THIS, value: instanceNamespace));
        }

        if (category == FunctionCategory.constructor &&
            redirectingConstructor != null) {
          late final HTFunction constructor;
          final name = redirectingConstructor!.name;
          final key = redirectingConstructor!.key;
          if (name == HTLexicon.SUPER) {
            final superClass = klass!.superClass!;
            if (key == null) {
              constructor = superClass
                  .namespace.declarations[SemanticNames.constructor]!.value;
            } else {
              constructor = superClass.namespace
                  .declarations['${SemanticNames.constructor}$key']!.value;
            }
          } else if (name == HTLexicon.THIS) {
            if (key == null) {
              constructor = klass!
                  .namespace.declarations[SemanticNames.constructor]!.value;
            } else {
              constructor = klass!.namespace
                  .declarations['${SemanticNames.constructor}$key']!.value;
            }
          }

          // constructor's context is on this newly created instance
          final instanceNamespace = namespace as HTInstanceNamespace;
          constructor.namespace = instanceNamespace.next!;

          final referCtorPosArgs = [];
          final referCtorPosArgIps = redirectingConstructor!.positionalArgsIp;
          for (var i = 0; i < referCtorPosArgIps.length; ++i) {
            final arg = interpreter.execute(
                moduleFullName: moduleFullName,
                libraryName: libraryName,
                ip: referCtorPosArgIps[i],
                namespace: callClosure);
            referCtorPosArgs.add(arg);
          }

          final referCtorNamedArgs = <String, dynamic>{};
          final referCtorNamedArgIps = redirectingConstructor!.namedArgsIp;
          for (final name in referCtorNamedArgIps.keys) {
            final referCtorNamedArgIp = referCtorNamedArgIps[name]!;
            final arg = interpreter.execute(
                moduleFullName: moduleFullName,
                libraryName: libraryName,
                ip: referCtorNamedArgIp,
                namespace: callClosure);
            referCtorNamedArgs[name] = arg;
          }

          constructor.call(
              positionalArgs: referCtorPosArgs,
              namedArgs: referCtorNamedArgs,
              createInstance: false);
        }

        var variadicStart = -1;
        HTParameter? variadicParam;
        for (var i = 0; i < paramDecls.length; ++i) {
          var decl = paramDecls.values.elementAt(i).clone();
          final paramId = paramDecls.keys.elementAt(i);
          callClosure.define(paramId, decl);

          if (decl.isVariadic) {
            variadicStart = i;
            variadicParam = decl;
            break;
          } else {
            if (i < maxArity) {
              if (i < positionalArgs.length) {
                decl.value = positionalArgs[i];
              } else {
                decl.initialize();
              }
            } else {
              if (namedArgs.containsKey(decl.id)) {
                decl.value = namedArgs[decl.id];
              } else {
                decl.initialize();
              }
            }
          }
        }

        if (variadicStart >= 0) {
          final variadicArg = <dynamic>[];
          for (var i = variadicStart; i < positionalArgs.length; ++i) {
            variadicArg.add(positionalArgs[i]);
          }
          variadicParam!.value = variadicArg;
        }

        if (category != FunctionCategory.constructor) {
          result = interpreter.execute(
              moduleFullName: moduleFullName,
              libraryName: libraryName,
              ip: definitionIp,
              namespace: callClosure,
              function: this,
              line: definitionLine,
              column: definitionColumn);
        } else {
          interpreter.execute(
              moduleFullName: moduleFullName,
              libraryName: libraryName,
              ip: definitionIp,
              namespace: callClosure,
              function: this,
              line: definitionLine,
              column: definitionColumn);
        }
      }
      // 如果是外部函数
      else {
        late final List<dynamic> finalPosArgs;
        late final Map<String, dynamic> finalNamedArgs;

        if (hasParamDecls) {
          if (positionalArgs.length < minArity ||
              (positionalArgs.length > maxArity && !isVariadic)) {
            throw HTError.arity(internalName, positionalArgs.length, minArity,
                moduleFullName: interpreter.curModuleFullName,
                line: interpreter.curLine,
                column: interpreter.curColumn);
          }

          for (final name in namedArgs.keys) {
            if (!paramDecls.containsKey(name)) {
              throw HTError.namedArg(name,
                  moduleFullName: interpreter.curModuleFullName,
                  line: interpreter.curLine,
                  column: interpreter.curColumn);
            }
          }

          finalPosArgs = [];
          finalNamedArgs = {};

          var variadicStart = -1;
          // HTBytecodeVariable? variadicParam;
          var i = 0;
          for (var param in paramDecls.values) {
            var decl = param.clone();

            if (decl.isVariadic) {
              variadicStart = i;
              // variadicParam = decl;
              break;
            } else {
              if (i < maxArity) {
                if (i < positionalArgs.length) {
                  decl.value = positionalArgs[i];
                  finalPosArgs.add(decl.value);
                } else {
                  decl.initialize();
                  finalPosArgs.add(decl.value);
                }
              } else {
                if (namedArgs.containsKey(decl.id)) {
                  decl.value = namedArgs[decl.id];
                  finalNamedArgs[decl.id] = decl.value;
                } else {
                  decl.initialize();
                  finalNamedArgs[decl.id] = decl.value;
                }
              }
            }

            ++i;
          }

          if (variadicStart >= 0) {
            final variadicArg = <dynamic>[];
            for (var i = variadicStart; i < positionalArgs.length; ++i) {
              variadicArg.add(positionalArgs[i]);
            }

            finalPosArgs.add(variadicArg);
          }
        } else {
          finalPosArgs = positionalArgs;
          finalNamedArgs = namedArgs;
        }

        if (klass != null) {
          // a method of a external class
          if (klass!.isExternal) {
            if (category != FunctionCategory.getter) {
              if (externalFunc == null) {
                if (isStatic || (category == FunctionCategory.constructor)) {
                  final classId = klass!.id!;
                  final externClass = interpreter.fetchExternalClass(classId);
                  final funcName = id != null ? '$classId.$id' : classId;
                  externalFunc = externClass.memberGet(funcName);
                } else {
                  throw HTError.missingExternalFunc(internalName,
                      moduleFullName: interpreter.curModuleFullName,
                      line: interpreter.curLine,
                      column: interpreter.curColumn);
                }
              }
              final func = externalFunc!;
              if (func is HTExternalFunction) {
                result = func(
                    positionalArgs: finalPosArgs,
                    namedArgs: finalNamedArgs,
                    typeArgs: typeArgs);
              } else if (func is Function) {
                result = Function.apply(
                    func,
                    finalPosArgs,
                    finalNamedArgs.map<Symbol, dynamic>(
                        (key, value) => MapEntry(Symbol(key), value)));
              } else {
                throw HTError.notCallable(internalName,
                    moduleFullName: interpreter.curModuleFullName,
                    line: interpreter.curLine,
                    column: interpreter.curColumn);
              }
            } else {
              final classId = klass!.id!;
              final externClass = interpreter.fetchExternalClass(classId);
              final funcName = isStatic ? '$classId.$id' : id!;
              result = externClass.memberGet(funcName);
            }
          }
          // a external method in a normal class
          else {
            final func = externalFunc ??
                interpreter.fetchExternalFunction('${klass!.name}.$id');
            if (func is HTExternalMethod) {
              HTInstance instance = result;
              result = func(instance,
                  positionalArgs: finalPosArgs,
                  namedArgs: finalNamedArgs,
                  typeArgs: typeArgs);
            } else {
              throw HTError.notCallable(internalName,
                  moduleFullName: interpreter.curModuleFullName,
                  line: interpreter.curLine,
                  column: interpreter.curColumn);
            }
          }
        }
        // a normal standalone external function
        else {
          final func =
              externalFunc ?? interpreter.fetchExternalFunction(internalName);

          if (func is HTExternalFunction) {
            result = func(
                positionalArgs: finalPosArgs,
                namedArgs: finalNamedArgs,
                typeArgs: typeArgs);
          } else if (func is Function) {
            result = Function.apply(
                func,
                finalPosArgs,
                finalNamedArgs.map<Symbol, dynamic>(
                    (key, value) => MapEntry(Symbol(key), value)));
          } else {
            throw HTError.notCallable(internalName,
                moduleFullName: interpreter.curModuleFullName,
                line: interpreter.curLine,
                column: interpreter.curColumn);
          }
        }
      }

      // if (category != FunctionCategory.constructor) {
      //   if (returnType != HTType.ANY) {
      //     final encapsulation = interpreter.encapsulate(result);
      //     if (encapsulation.valueType.isNotA(returnType)) {
      //       throw HTError.returnType(
      //           encapsulation.valueType.toString(), id, returnType.toString());
      //     }
      //   }
      // }

      if (interpreter.stackTrace.isNotEmpty) {
        interpreter.stackTrace.removeLast();
      }

      return result;
    } catch (error, stackTrace) {
      if (errorHandled) {
        rethrow;
      } else {
        interpreter.handleError(error, externalStackTrace: stackTrace);
      }
    }
  }
}
