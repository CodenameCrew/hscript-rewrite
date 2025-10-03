package hscript;

import haxe.ds.StringMap;
import haxe.ds.Vector;
import hscript.Ast.VariableInfo;
import hscript.Ast.EImportMode;
import haxe.ds.Either;
import hscript.Ast.Argument;
import hscript.Ast.SwitchCase;
import haxe.Constraints.Function;
import hscript.Ast.Expr;
import hscript.Error.ErrorDef;
import hscript.Ast.VariableType;
import hscript.Lexer.LConst;
import hscript.Ast.ExprBinop;
import haxe.Constraints.IMap;
import hscript.Ast.IHScriptCustomBehaviour;
import haxe.PosInfos;

private enum IStop {
    ISBreak;
    ISContinue;
    ISReturn;
}

private enum IScriptParentType {
    ISObject;
    ISNone;
}

@:structInit
private class IVariableScopeChange {
    public var old:IVariableScopeChange;

    public var oldDeclared:Bool;
    public var oldValue:Dynamic;
    public var scope:Int;
}

@:allow(hscript)
interface IInterp {
    private var variablesDeclared:Vector<Bool>;
    private var variablesValues:Vector<Dynamic>;

    private var variableNames:Vector<String>;
    private var variablesLookup:StringMap<Int>;

    private function assign(name:VariableType, value:Dynamic):Dynamic;
}

class Interp implements IInterp {
    /**
     * Our variables used no matter what scope, fastest by far winner when it comes to raw reading and writing.
     * 
     * Two arrays (mixed): 31.8157 ms
     * Enum array (mixed): 188.1146 ms
     * IntMap (mixed): 146.5216 ms
     * Sentinel enum array (mixed): 125.6402 ms
     * Int sentinel array (mixed): 18.828 ms (not accounting for overhead of collisions)
     * Object array (mixed): 200.3166 ms
     * 
     * Scope changes will create variable changes that will be popped and reversed on the main array see changes array.
     * hopefully this is the right choice and doesn't give any headaches later :D -lunar
     */
    private var variablesDeclared:Vector<Bool>;
    private var variablesValues:Vector<Dynamic>;

    /**
     * Use variablesLookup.get(s) instead of variableNames.
     * 
     * If variableNames was a Array<String> it would be a linear scan across array.
     * The variablesLookup map is generated in loadTables() function.
     * 
     * Linear scan Array: 2.359025s
     * Linear scan Vector: 2.3816353s
     * Array.indexOf: 2.0919545s
     * Map lookup: 0.0215189000000002s
     */
    private var variableNames:Vector<String>;
    private var variablesLookup:StringMap<Int>;

    private var changes:Vector<IVariableScopeChange>;

    private var scope:Int = 0;
    private var inTry:Bool = false;
    private var returnValue:Dynamic = null;

    public var fileName:String = null;
    public var lineNumber:Int = 0;

    public var variables:InterpLocals;
    public var publicVariables:StringMap<Dynamic>;
    public var errorHandler:Error->Void;

    public var hasScriptParent:Bool = false;
    public var scriptParent(default, set):Dynamic;
    public var scriptParentType:IScriptParentType = ISNone;
    public var scriptParentFields:StringMap<Bool>;

    public function set_scriptParent(value:Dynamic):Dynamic {
        if (value == null) {
            scriptParentFields = null;
            hasScriptParent = false;
            scriptParentType = ISNone;
            return scriptParent = null;
        }

        if (scriptParentFields == null)
            scriptParentFields = new StringMap<Bool>();
        scriptParentFields.clear();

        hasScriptParent = true;
        switch (Type.typeof(value)) {
            case TClass(cls):
                for (field in Type.getInstanceFields(cls)) scriptParentFields.set(field, true);
                scriptParentType = ISObject;
            case TObject:
                for (field in Reflect.fields(value)) scriptParentFields.set(field, true);
                scriptParentType = ISObject;
            default:
                hasScriptParent = false;
                scriptParentType = ISNone;
        }

        return scriptParent = value;
    }

    public function new(?fileName:String) {
        this.fileName = fileName ?? "";
        this.variables = new InterpLocals(this);
    }

    public function execute(expr:Expr):Dynamic {
        switch (expr.expr) {
            case EInfo(info, expr):
                loadTables(info);
                loadBaseVariables();

                return safeInterpReturnExpr(expr);
            default:
                throw error(ECustom("Missing EInfo()"), expr.line);
        }
    }

    public function reset() {
        this.variablesDeclared = null;
        this.variablesValues = null;

        this.variableNames = null;
        this.variablesLookup = null;
        this.changes = null;

        this.variables.useDefaults = true;
        this.variables.defaultsValues.clear();

        this.scope = 0;
        this.inTry = false;
        this.returnValue = null;
    }

    private function loadTables(info:VariableInfo) {
        variablesDeclared = new Vector<Bool>(info.length);
        variablesValues = new Vector<Dynamic>(info.length);

        variableNames = Vector.fromArrayCopy(info);
        variablesLookup = new StringMap<Int>();
        for (i => name in info) variablesLookup.set(name, i);

        changes = new Vector<IVariableScopeChange>(info.length);
    }

    private function loadBaseVariables() {
        variables.set("null", null);
        variables.set("true", true);
        variables.set("false", false);
        variables.set("trace", Reflect.makeVarArgs(function (vals:Array<Dynamic>) {
            var info:PosInfos = cast {
                lineNumber: this.lineNumber,
                fileName: this.fileName,
            };
            var value:Dynamic = vals.shift();
			if (vals.length > 0) info.customParams = vals;
			haxe.Log.trace(Std.string(value), info);
        }));

        variables.loadDefaults();
    }

    private function interpExpr(expr:Expr):Dynamic {
        if (expr == null) return null;

        this.lineNumber = expr.line;
        return switch (expr.expr) {
            case EMeta(name, args, expr): interpExpr(expr);
            case EConst(const): StaticInterp.evaluateConst(const);
            case EIdent(name): if (variablesDeclared[name]) variablesValues[name]; else resolveGlobal(name);
            case EVar(name, init, isPublic, isStatic):
                if (scope == 0) {
                    var varName:String = variableNames[name];
                    if (isStatic && !StaticInterp.staticVariables.exists(varName)) {
                        StaticInterp.staticVariables.set(varName, interpExpr(init));
                        return null;
                    }
                    if (isPublic && publicVariables != null) {
                        publicVariables.set(variableNames[name], interpExpr(init));
                        return null;
                    }
                }
                assign(name, init == null ? null : interpExpr(init));
                return null;
            case EBinop(op, left, right): 
                switch (op) {
                    case ADD_ASSIGN | SUB_ASSIGN | MULT_ASSIGN | DIV_ASSIGN | MOD_ASSIGN | SHL_ASSIGN | 
                        SHR_ASSIGN | USHR_ASSIGN | OR_ASSIGN | AND_ASSIGN | XOR_ASSIGN | NCOAL_ASSIGN: assignExprOp(op, left, right);
                    case ASSIGN: assignExpr(left, right);
                    default: StaticInterp.evaluateBinop(op, interpExpr(left), interpExpr(right));
                }
            case EParent(expr): interpExpr(expr);
            case EBlock(exprs):
                var value:Dynamic = null;
                for (expr in exprs)
                    value = interpExpr(expr);
                value;
            case EField(expr, field, isSafe): if (isSafe && field == null) null else StaticInterp.getObjectField(interpExpr(expr), field);
            case EUnop(op, isPrefix, expr):
                switch (op) {
                    case INC: assignExprOp(ADD_ASSIGN, expr, new Expr(EConst(LCInt(1)), expr.line));
                    case DEC: assignExprOp(ADD_ASSIGN, expr, new Expr(EConst(LCInt(-1)), expr.line));
                    case NOT: !interpExpr(expr);
                    case NEG: -interpExpr(expr);
                    case NEG_BIT: ~interpExpr(expr);
                }
            case ECall(func, args):
                var argValues:Array<Dynamic> = [for (arg in args) interpExpr(arg)];
                switch (func.expr) {
                    case EField(expr, field, isSafe):
                        var object:Dynamic = interpExpr(expr);
                        if (object == null) {
                            if (!isSafe) error(EInvalidAccess(field), expr.line);
                            else null;
                        }
                        return StaticInterp.callObjectField(object, StaticInterp.getObjectField(object, field), argValues);
                    default: return StaticInterp.callObjectField(null, interpExpr(func), argValues);
                }
            case EIf(cond, thenExpr, elseExpr):
                return if (interpExpr(cond) == true) 
                    interpExpr(thenExpr);
                else if (elseExpr != null)
                    interpExpr(elseExpr);
                else null;
            case ETernary(cond, thenExpr, elseExpr): 
                return if (interpExpr(cond) == true) interpExpr(thenExpr);
                else interpExpr(elseExpr);
            case EBreak: throw ISBreak;
            case EContinue: throw ISContinue;
            case EMapDecl(keys, values): interpMap([for (key in keys) interpExpr(key)], [for (val in values) interpExpr(val)]);
            case EArrayDecl(items): [for (item in items) interpExpr(item)];
            case EArray(expr, index):
                var array:Dynamic = interpExpr(expr);
                var index:Dynamic = interpExpr(index);

                if (array is IMap) StaticInterp.getMapValue(array, index);
                else array[index];
            case ENew(className, args): interpNew(className, args);
            case EThrow(expr): throw interpExpr(expr);
            case EObject(fields):
                if (fields == null || fields.length <= 0) return {};
                var object:Dynamic = {};
                for (field in fields) 
                    Reflect.setField(object, field.name, interpExpr(field.expr));

                object;
            case EForKeyValue(key, value, iterator, body): forKeyValueLoop(key, value, iterator, body); null;
            case EFor(varName, iterator, body): forLoop(varName, iterator, body); null;
            case EWhile(cond, body): whileLoop(cond, body); null;
            case EDoWhile(cond, body): doWhileLoop(cond, body); null;
            case ESwitch(expr, cases, defaultExpr): interpSwitch(expr, cases, defaultExpr);
            case EFunction(args, body, name, isPublic, isStatic): interpFunction(args, body, name, isPublic, isStatic);
            case ETry(expr, catchVar, catchExpr): interpTry(expr, catchVar, catchExpr);
            case EReturn(expr):
                returnValue = expr == null ? null : interpExpr(expr);
                throw ISReturn;
            case EImport(path, mode): 
                var importValue:Dynamic = interpImport(path, mode);
                if (importValue == null) error(EInvalidClass(path), expr.line);
                return importValue;
            case EInfo(info, _): error(ECustom("Invalid EInfo()"), expr.line);
        }
    }

    private inline function interpReturnExpr(expr:Expr):Dynamic {
        try {
            return interpExpr(expr);
        } catch (stop:IStop) {
            switch (stop) {
                case ISBreak: throw "Invalid break";
                case ISContinue: throw "Invalid continue";
                case ISReturn:
                    var value:Dynamic = returnValue;
                    returnValue = null;
                    return value;
            }
        } catch (e) {
            error(ECustom(e.toString()));
            return null;
        }
    }

    /**
     * Catch errors that are not raised by the script, but are raised by the Interp.
     */
    private function safeInterpReturnExpr(expr:Expr):Dynamic {
        try {
            return interpReturnExpr(expr);
        } catch (e:Error) {
            Sys.println(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
			if (errorHandler != null) errorHandler(e);
			else throw e;
			return null;
        } catch (e) {
            trace(e);
        }
        return null;
    }

    private function interpImport(path:String, mode:EImportMode):Dynamic {
        if (mode == All) return null; // not implemented

        var splitPathName:Array<String> = path.split(".");
        if (splitPathName.length <= 0) return null;

        var lastPathName:String = splitPathName[splitPathName.length-1];
        var variableName:String = switch (mode) {
            case As(name): name;
            default: lastPathName;
        }

        if (variablesLookup.exists(variableName)) {
            var variableID:VariableType = variablesLookup.get(variableName);
            if (variablesDeclared[variableID]) return variablesValues[variableID];
        }

        var testClass:Either<Class<Dynamic>, Enum<Dynamic>> = StaticInterp.resolvePath(path);
        if (testClass == null) {
            var splitPathCopy:Array<String> = splitPathName.copy();
            splitPathCopy.pop();

            testClass = StaticInterp.resolvePath(splitPathCopy.join("."));
        }

        if (testClass != null) {
            var value:Dynamic = switch (testClass) {
                case Left(resolvedClass): resolvedClass;
                case Right(rawEnum): StaticInterp.resolveEnum(rawEnum);
            }

            if (variablesLookup.exists(variableName)) 
                assign(variablesLookup.get(variableName), value);

            return value;
        }

        return null;
    } 

    private function interpFunction(args:Array<Argument>, body:Expr, name:VariableType, ?isPublic:Bool, ?isStatic:Bool) {
        var argsNeeded:Int = 0;
        for (arg in args) if (!arg.opt) argsNeeded++;

        var reflectiveFunction:Dynamic = null;
        var interpFunction:Dynamic = function (inputArgs:Array<Dynamic>) {
            if ((inputArgs == null ? 0 : inputArgs.length) != argsNeeded) {
                error(ECustom(
                    "Invalid number of parameters. Got " + inputArgs.length + ", required " + argsNeeded +
                    (name != null ? " for function '" + name + "'" : "")
                ), body.line);

                var fixedArgs:Array<Dynamic> = [];
                var extraArgs:Int = inputArgs.length - argsNeeded;
                var position:Int = 0;

                for (arg in args) {
                    if (arg.opt) {
                        if (extraArgs > 0) {
                            fixedArgs.push(inputArgs[position++]);
                            extraArgs--;
                        } else fixedArgs.push(null);
                    } else fixedArgs.push(inputArgs[position++]);
                }

                inputArgs = fixedArgs;
            }

            increaseScope();
            assign(name, reflectiveFunction); // self recurssion

            for (arg in 0...args.length) assign(args[arg].name, inputArgs[arg]);
            var ret:Dynamic = null;

            if (inTry) {
                try {
                    ret = interpReturnExpr(body);
                } catch (error:Dynamic) {
                    decreaseScope();
                    throw error;
                }
            } else {
                ret = interpReturnExpr(body);
            }

            decreaseScope();
            return ret;
        }

        reflectiveFunction = Reflect.makeVarArgs(interpFunction);
        if (name != null) {
            if (scope == 0) {
                var varName:String = variableNames[name];
                if (isStatic && !StaticInterp.staticVariables.exists(varName)) {
                    StaticInterp.staticVariables.set(varName, reflectiveFunction);
                    return reflectiveFunction;
                }
                if (isPublic && publicVariables != null) {
                    publicVariables.set(variableNames[name], reflectiveFunction);
                    return reflectiveFunction;
                }
            }
            assign(name, reflectiveFunction);
        }
        return reflectiveFunction;
    }

    private inline function interpTry(expr, catchVar, catchExpr):Dynamic {
        var oldTryState:Bool = inTry;
        increaseScope();
        
        try {
            inTry = true;
            var value:Dynamic = interpExpr(expr);
            decreaseScope();

            inTry = oldTryState;
            return value;
        } catch (stop:IStop) {
            inTry = oldTryState;
            decreaseScope();
            throw stop;
        } catch (error:Dynamic) {
            inTry = oldTryState;
            decreaseScope();

            increaseScope();
            assign(catchVar, error);
            var value:Dynamic = interpExpr(catchExpr);
            decreaseScope();

            return value;
        }
    }

    private inline function forKeyValueLoop(key:VariableType, value:VariableType, iterator:Expr, body:Expr) {
        increaseScope();

        assign(key, null);
        assign(value, null);

        var iterator:KeyValueIterator<Dynamic, Dynamic> = makeKeyValueIteratorExpr(iterator);
        while (iterator.hasNext()) {
            var iteratorValue:Dynamic = iterator.next();
            assign(key, iteratorValue.key);
            assign(value, iteratorValue.value);
            if (!interpLoop(body)) break;
        }

        decreaseScope();
    }

    private inline function forLoop(varName:VariableType, iterator:Expr, body:Expr) {
        increaseScope();

        assign(varName, null);

        var iterator:Iterator<Dynamic> = makeIteratorExpr(iterator);
        while (iterator.hasNext()) {
            assign(varName, iterator.next());
            if (!interpLoop(body)) break;
        }

        decreaseScope();
    }

    private inline function makeIteratorExpr(expr:Expr):Iterator<Dynamic> {
        var untypedIterator:Dynamic = interpExpr(expr);
        var iterator:Iterator<Dynamic> = makeIterator(untypedIterator);
        return iterator == null ? throw error(EInvalidIterator(untypedIterator), expr.line) : iterator;
    }

    private inline function makeKeyValueIteratorExpr(expr:Expr):KeyValueIterator<Dynamic, Dynamic> {
        var untypedIterator:Dynamic = interpExpr(expr);
        var iterator:KeyValueIterator<Dynamic, Dynamic> = makeKeyValueIterator(untypedIterator);
        return iterator == null ? throw error(EInvalidIterator(untypedIterator), expr.line) : iterator;
    }

    private inline function makeIterator(value:Dynamic):Iterator<Dynamic> {
        // https://github.com/HaxeFoundation/hscript/blob/master/hscript/Interp.hx#L572-L584
		#if js // don't use try/catch (very slow)
		if(value is Array) return (value:Array<Dynamic>).iterator();
		if(value.iterator != null) value = value.iterator();
		#else
		#if (cpp) if (value.iterator != null) #end
			try value = value.iterator() catch(e:Dynamic) {};
		#end
		if(value.hasNext == null || value.next == null) return null;
		return value;
	}

	private inline function makeKeyValueIterator(value:Dynamic):KeyValueIterator<Dynamic,Dynamic> {
        //https://github.com/HaxeFoundation/hscript/blob/master/hscript/Interp.hx#L586-L597
		#if js // don't use try/catch (very slow)
		if(value is Array) return (value:Array<Dynamic>).keyValueIterator();
		if(value.iterator != null) value = value.keyValueIterator();
		#else
		try value = value.keyValueIterator() catch(e:Dynamic) {};
		#end
		if(value.hasNext == null || value.next == null) return null;
		return value;
	}

    private inline function whileLoop(cond:Expr, body:Expr) {
        increaseScope();

        while (interpExpr(cond) == true) {
            if (!interpLoop(body)) break;
        }

        decreaseScope();
    }

    private inline function doWhileLoop(cond:Expr, body:Expr) {
        increaseScope();

        do {
            if (!interpLoop(body)) break;
        } while (interpExpr(cond) == true);

        decreaseScope();
    }

    private inline function interpLoop(expr:Expr):Bool {
        var continueLoop:Bool = true;

        try {
            interpExpr(expr);
        } catch (stop:IStop) {
            switch (stop) {
                case ISContinue:
                case ISBreak: continueLoop = false;
                case ISReturn: throw stop;
            }
        }
        return continueLoop;
    }

    private inline function interpSwitch(expr:Expr, cases:Array<SwitchCase>, defaultExpr:Expr):Dynamic {
        var switchValue:Dynamic = interpExpr(expr);
        var foundMatch:Bool = false;

        for (switchCase in cases) {
            for (value in switchCase.values)
                if (interpExpr(value) == switchValue) {foundMatch = true; break;}

            if (foundMatch && switchCase.expr != null) switchValue = interpExpr(switchCase.expr);
        }

        if (!foundMatch) switchValue = defaultExpr != null ? interpExpr(defaultExpr) : null;
        return switchValue;
    }

    private inline function interpNew(className:VariableType, args:Array<Dynamic>):Dynamic {
        var classType = if (variablesDeclared[className]) variablesValues[className] else Type.resolveClass(variableNames[className]);

        if (classType == null) classType = resolveGlobal(className);
        return Type.createInstance(classType, args);
    }

    private inline function interpMap(keys:Array<Dynamic>, values:Array<Dynamic>):Dynamic {
        // https://github.com/HaxeFoundation/hscript/blob/master/hscript/Interp.hx#L655-L664
        var isAllString:Bool = true;
		var isAllInt:Bool = true;
		var isAllObject:Bool = true;
		var isAllEnum:Bool = true;

		for (key in keys) {
			isAllString = isAllString && (key is String);
			isAllInt = isAllInt && (key is Int);
			isAllObject = isAllObject && Reflect.isObject(key);
			isAllEnum = isAllEnum && Reflect.isEnumValue(key);
		}

        var map:IMap<Dynamic, Dynamic> = {
            if (isAllInt) new haxe.ds.IntMap<Dynamic>();
			else if (isAllString) new haxe.ds.StringMap<Dynamic>();
			else if (isAllEnum) new haxe.ds.EnumValueMap<Dynamic, Dynamic>();
			else if (isAllObject) new haxe.ds.ObjectMap<Dynamic, Dynamic>();
			else new haxe.ds.Map<Dynamic, Dynamic>();
        }

        for (i in 0...keys.length)
            map.set(keys[i], values[i]);

        return map;
    }

    private inline function assignExpr(left:Expr, right:Expr):Dynamic {
        var assignValue:Dynamic = interpExpr(right);
        return switch (left.expr) {
            case EIdent(name): 
                var varName:String = variableNames[name];
                if (isScriptParentField(varName))
                    return setScriptParentField(varName, assignValue);
                assign(name, assignValue);
            case EField(expr, field, isSafe):
                var object:Dynamic = interpExpr(expr);
                if (isSafe && object == null) return null;
                StaticInterp.setObjectField(object, field, assignValue);

                assignValue;
            case EArray(expr, index):
                var array:Dynamic = interpExpr(expr);
                var index:Dynamic = interpExpr(index);

                if (array is IMap) StaticInterp.setMapValue(array, index, assignValue);
                else array[index] = assignValue;

                assignValue;
            default: error(EInvalidOp(EQ), left.line);
        }
    }

    private inline function assignExprOp(op:ExprBinop, left:Expr, right:Expr):Dynamic {
        return switch (left.expr) {
            case EIdent(name): 
                if (variablesDeclared[name])
                    assign(name, StaticInterp.evaluateBinop(op, interpExpr(left), interpExpr(right)));
                else {
                    var varName:String = variableNames[name];

                    if (isScriptParentField(varName)) {
                        var value:Dynamic = getScriptParentField(varName);
                        var newValue:Dynamic = StaticInterp.evaluateBinop(op, value, interpExpr(right));

                        setScriptParentField(varName, newValue);
                        return newValue;
                    }

                    if (StaticInterp.staticVariables.exists(varName)) {
                        var value:Dynamic = StaticInterp.staticVariables.get(varName);
                        var newValue:Dynamic = StaticInterp.evaluateBinop(op, value, interpExpr(right));

                        StaticInterp.staticVariables.set(varName, newValue);
                        return newValue;
                    }
                    
                    if (publicVariables != null && publicVariables.exists(varName)) {
                        var value:Dynamic = publicVariables.get(varName);
                        var newValue:Dynamic = StaticInterp.evaluateBinop(op, value, interpExpr(right));

                        publicVariables.set(varName, newValue);
                        return newValue;
                    }

                    error(EUnknownVariable(varName), left.line);
                }
            case EField(expr, field, isSafe):
                var object:Dynamic = interpExpr(expr);
                if (object == null) {
                    if (!isSafe) error(EInvalidAccess(field), expr.line);
                    else null;
                } else {
                    var fieldValue:Dynamic = StaticInterp.getObjectField(object, field);
                    var assignValue:Dynamic = interpExpr(right);

                    StaticInterp.setObjectField(object, field, StaticInterp.evaluateBinop(op, fieldValue, assignValue));
                }
            case EArray(expr, index):
                var array:Dynamic = interpExpr(expr);
                var index:Dynamic = interpExpr(index);

                var assignValue:Dynamic = null;
                if (array is IMap) {
                    assignValue = StaticInterp.evaluateBinop(op, StaticInterp.getMapValue(array, index), interpExpr(right));
                    StaticInterp.setMapValue(array, index, assignValue);
                } else {
                    assignValue = StaticInterp.evaluateBinop(op, array[index], interpExpr(right));
                    array[index] = assignValue;
                }
                assignValue;
            default: error(EInvalidOp(op), left.line);
        }
    }

    private inline function assign(name:VariableType, value:Dynamic):Dynamic {
        if (scope > 0 && (changes[name] == null || changes[name].scope <= this.scope)) {
            changes.set(name, {
                old: changes[name],
                oldDeclared: variablesDeclared[name],
                oldValue: variablesValues[name],
                scope: this.scope
            });
        }

        variablesDeclared[name] = true;
        variablesValues[name] = value;

        return value;
    }

    private inline function increaseScope() {this.scope++;}

    private inline function decreaseScope() {
        this.scope--;
        scopeChanges();
    }

    private inline function scopeChanges() {
        for (name in 0...changes.length) {
            var change:IVariableScopeChange = changes.get(name);
            if (change != null && change.scope > this.scope) {
                if (change.oldDeclared) {
                    variablesDeclared[name] = true;
                    variablesValues[name] = change.oldValue;
                } else {
                    variablesDeclared[name] = false;
                    variablesValues[name] = null;
                }
                
                if (change.old != null) changes[name] = change.old;
            }
        }
    }

    /**
     * !!!USE THIS FUNCTION TO FIND THINGS THAT ARE NOT DEFINED BY SCRIPT!!!
     * Idents go to the resolve function when they aren't defined in the local scope of the program.
     * 
     * For example:
     * public var x:Float = 1;
     * static var y:Float = 3;
     * var z:Float = 3;
     * 
     * trace(x); calls resolve, not local
     * trace(y); calls resolve, not local
     * 
     * trace(z); does not call resolve, local
     */
    private inline function resolve(varName:String):Dynamic {
        error(EUnknownVariable(varName), this.lineNumber);
    }

    private inline function resolveGlobal(ident:VariableType):Dynamic {
        var varName:String = variableNames[ident];
        if (isScriptParentField(varName)) return getScriptParentField(varName);
        if (StaticInterp.staticVariables.exists(varName)) return StaticInterp.staticVariables.get(varName);
        if (publicVariables != null && publicVariables.exists(varName)) return publicVariables.get(varName);
        return resolve(varName);
    }

    private inline function isScriptParentField(field:String):Bool {
        return hasScriptParent && scriptParentFields.exists(field);
    }
    
    private inline function getScriptParentField(field:String):Dynamic {
        switch (scriptParentType) {
            case ISObject: return StaticInterp.getObjectField(scriptParent, field);
            case ISNone: return null;
        }
    }

    private inline function setScriptParentField(field:String, value:Dynamic):Dynamic {
        switch (scriptParentType) {
            case ISObject: return StaticInterp.setObjectField(scriptParent, field, value);
            case ISNone: return null;
        }
    }

    private inline function error(err:ErrorDef, ?line:Int):Dynamic {
		throw new Error(err, null, null, this.fileName, line ?? this.lineNumber);
        return null;
	}
}

class StaticInterp {
	public static var staticVariables:StringMap<Dynamic> = new StringMap<Dynamic>();
    
    public static inline function evaluateBinop(op:ExprBinop, val1 :Dynamic, val2:Dynamic):Dynamic {
        switch (op) {
            case ADD: return val1 + val2;
            case SUB: return val1 - val2;
            case MULT: return val1 * val2;
            case DIV: return val1 / val2;
            case MOD: return val1 % val2;

            case AND: return val1 & val2;
            case OR: return val1 | val2;
            case XOR: return val1 ^ val2;
            case SHL: return val1 << val2;
            case SHR: return val1 >> val2;
            case USHR: return val1 >>> val2;

            case EQ: return val1 == val2;
            case NEQ: return val1 != val2;
            case GTE: return val1 >= val2;
            case LTE: return val1 <= val2;
            case GT: return val1 > val2;
            case LT: return val1 < val2;

            case ADD_ASSIGN: return val1 + val2;
            case SUB_ASSIGN: return val1 - val2;
            case MULT_ASSIGN: return val1 * val2;
            case DIV_ASSIGN: return val1 / val2;
            case MOD_ASSIGN: return val1 % val2;
            case SHL_ASSIGN: return val1 << val2;
            case SHR_ASSIGN: return val1 >> val2;
            case USHR_ASSIGN: return val1 >>> val2;
            case OR_ASSIGN: return val1 | val2;
            case AND_ASSIGN: return val1 & val2;
            case XOR_ASSIGN: return val1 ^ val2;
            case NCOAL_ASSIGN: return val1 ?? val2;

            case BOR: return val1 || val2;
            case BAND: return val1 && val2;
            case IS: return Std.isOfType(val1 , val2);
            case NCOAL: return val1 ?? val2;

            default: throw new Error(EInvalidOp("Invalid operator: " + op));
        }
    }

    public static inline function evaluateConst(const:LConst):Dynamic {
        return switch (const) {
            case LCInt(int): int;
            case LCFloat(float): float;
            case LCString(string): string;
        }
    }

    // https://github.com/HaxeFoundation/hscript/blob/master/hscript/Interp.hx#L646-L652
	public static inline function getMapValue(map:Dynamic, key:Dynamic):Dynamic {
		return cast(map, IMap<Dynamic, Dynamic>).get(key);
	}

	public static inline function setMapValue(map:Dynamic, key:Dynamic, value:Dynamic):Void {
		cast(map, IMap<Dynamic, Dynamic>).set(key, value);
	}

    public static function resolvePath(path:String):Either<Class<Dynamic>, Enum<Dynamic>> {
        var resolvedClass:Class<Dynamic> = Type.resolveClass(path);
        if (resolvedClass != null) return Left(resolvedClass);

        var resolvedEnum:Enum<Dynamic> = Type.resolveEnum(path);
        if (resolvedEnum != null) return Right(resolvedEnum);

        return null;
    }

    public static function resolveEnum(enums:Enum<Dynamic>):Dynamic {
        var enumStorage:Dynamic = {};
        for (name in enums.getConstructors()) {
            try {
                Reflect.setField(enumStorage, name, enums.createByName(name));
            } catch (error:Dynamic) {
                try {
                    Reflect.setField(enumStorage, name, Reflect.makeVarArgs((args:Array<Dynamic>) -> enums.createByName(name, args)));
                } catch (e:Dynamic) {
                    throw error;
                }
            }
        }
        return enumStorage;
    }

    public static inline function getObjectField(object:Dynamic, field:String) {
        if (object is IHScriptCustomBehaviour) {
            var behavior:IHScriptCustomBehaviour = cast object;
            return behavior.hget(field);
        }

        return Reflect.getProperty(object, field);
    }

    public static inline function setObjectField(object:Dynamic, field:String, value:Dynamic) {
        if (object is IHScriptCustomBehaviour) {
            var behavior:IHScriptCustomBehaviour = cast object;
            return behavior.hset(field, value);
        }

        Reflect.setProperty(object, field, value);
        return value;
    }

    public static inline function callObjectField(object:Dynamic, field:Function, args:Array<Dynamic>) {
        return Reflect.callMethod(object, field, args);
    }
}

/**
 * Interface to set locals inside a interp. See resolve() function to see what counts as local.
 */
class InterpLocals {
    /**
     * Defaults are used to load variables before the interps variable vectors have loaded
     * 
     * For example:
     * interp.variables.set("input", 123);
     * interp.execute(expr);
     * 
     * without loadDefaults() the interp wouldn't know where to bind the input.
     */
    public var defaultsValues:Map<String, Dynamic> = [];
	public var useDefaults:Bool = true;

	public function loadDefaults() {
		useDefaults = false;
		for (key => value in defaultsValues) set(key, value);
	}
	public var parent:IInterp;

	public function new(parent:IInterp)
		this.parent = parent;

	public inline function set(key:String, value:Dynamic) {
        if (useDefaults) {
            defaultsValues.set(key, value);
        } else {
		    if (parent.variablesLookup.exists(key)) 
                parent.assign(parent.variablesLookup.get(key), value);
        }
	}

	public inline function get(key:String):Dynamic {
        if (useDefaults) {
            return defaultsValues.get(key);
        } else {
		    if (parent.variablesLookup.exists(key)) {
                var varID:Int = parent.variablesLookup.get(key);
                return parent.variablesDeclared[varID] ? parent.variablesValues[varID] : null; 
            } else 
                return null;
        }
	}

	public inline function exists(key:String):Bool {
		return parent.variablesLookup.get(key) != null;
	}
}