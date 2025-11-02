package hscript;

import haxe.ds.ObjectMap;
import haxe.ds.Map;
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
private class IDeclaredVariable {
    public var name:VariableType;
    public var oldDeclared:Bool;
    public var oldValue:Dynamic;
}

typedef IVariableReference = {
    public var r:Dynamic;
}

@:allow(hscript)
@:analyzer(optimize, local_dce, fusion, user_var_fusion)
class ScriptRuntime {
    /**
     * Our variables used no matter what scope, fastest by far winner when it comes to raw reading and writing.
     * 
     * Two arrays (mixed): 31.8157 ms
     * Enum array (mixed): 188.1146 ms
     * IntMap (mixed): 146.5216 ms
     * Int sentinel array (mixed): 18.828 ms (not accounting for overhead of collisions)
     * Object array (mixed): 200.3166 ms
     */
    private var variablesDeclared:Vector<Bool>;
    private var variablesValues:Vector<IVariableReference>;

    /**
     * Use variablesLookup.get(s) instead of variableNames.indexOf(s).
     * 
     * If variableNames was a Array<String> it would be a linear scan across array.
     * The variablesLookup map is generated in loadTables() function.
     */
    private var variableNames:Vector<String>;
    private var variablesLookup:StringMap<Int>;

    private var changes:Array<IDeclaredVariable> = [];

    private var depth:Int = 0;
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

    public function reset() {
        this.variablesDeclared = null;
        this.variablesValues = null;

        this.variableNames = null;
        this.variablesLookup = null;

        this.changes = [];

        this.variables.useDefaults = true;
        this.variables.defaultsValues.clear();

        this.depth = 0;
        this.inTry = false;
        this.returnValue = null;
    }

    private function loadTables(info:VariableInfo) {
        variablesDeclared = new Vector<Bool>(info.length);
        variablesValues = new Vector<IVariableReference>(info.length);
        for (i in 0...variablesValues.length) variablesValues[i] = {r: null};

        variableNames = Vector.fromArrayCopy(info);
        variablesLookup = new StringMap<Int>();
        for (i => name in info) variablesLookup.set(name, i);
    }

    private function loadBaseVariables() {
        // Set as many base variables as you want!! Will not stay in memory after the program is loaded!!! -lunar
        variables.set("Std", Std);
        variables.set("Math", Math);
        variables.set("Reflect", Reflect);
        variables.set("StringTools", StringTools);
        variables.set("Xml", Xml);
        variables.set("Type", Type);
        variables.set("Date", Date);
        variables.set("Lambda", Lambda);

        variables.set("Json", haxe.Json);
        variables.set("Base64", haxe.crypto.Base64);
        variables.set("Path", haxe.io.Path);
        variables.set("Timer", haxe.Timer);
        variables.set("EReg", EReg);
        variables.set("StringBuf", StringBuf);

        variables.set("Int", Int);
        variables.set("Float", Float);
        variables.set("Bool", Bool);
        variables.set("String", String);
        variables.set("Array", Array);

        #if sys 
        variables.set("Sys", Sys); 
        variables.set("File", sys.io.File);
        variables.set("FileSystem", sys.FileSystem);
        #end

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

    private inline function declare(name:VariableType, value:Dynamic):Dynamic {
        if (depth != 0) changes.push({
            name: name,
            oldDeclared: variablesDeclared[name],
            oldValue: variablesValues[name]
        });
        
        variablesDeclared[name] = true;
        variablesValues[name] = {r: value};

        return value;
    }

    private inline function declareReferenced(name:VariableType, ref:IVariableReference):Dynamic {
        if (depth != 0) changes.push({
            name: name,
            oldDeclared: variablesDeclared[name],
            oldValue: variablesValues[name]
        });
        
        variablesDeclared[name] = true;
        variablesValues[name] = ref;

        return ref.r;
    }

    private inline function assign(name:VariableType, value:Dynamic):Dynamic {
        variablesDeclared[name] = true;
        variablesValues[name].r = value;

        return value;
    }

    private function duplicate<T>(vector:Vector<T>):Vector<T> {
        var newVector:Vector<T> = new Vector(vector.length);
        for (i in 0...vector.length) newVector[i] = vector[i];
        return newVector;
	}

    private inline function store():Int {return changes.length;}

	private inline function restore(oldChangesIndex:Int) {
        while (changes.length > oldChangesIndex) {
            var change:IDeclaredVariable = changes.pop();
            var name:VariableType = change.name;

            if (change.oldDeclared) {
                variablesDeclared[name] = change.oldDeclared;
                variablesValues[name] = change.oldValue;
            } else {
                variablesDeclared[name] = false;
                variablesValues[name] = {r: null};
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
     * x += 2; calls resolve, not local
     * y += 2; calls resolve, not local
     * 
     * z += 2; does not call resolve, local
     */
    private function resolve(varName:String):Dynamic {
        error(EUnknownVariable(varName), this.lineNumber);
    }

    private function resolveGlobal(ident:VariableType):Dynamic {
        var varName:String = variableNames[ident];
                
        if (StaticInterp.staticVariables.exists(varName)) return StaticInterp.staticVariables.get(varName);
        if (publicVariables != null && publicVariables.exists(varName)) return publicVariables.get(varName);

        if (hasScriptParent) {
            if (isScriptParentField(varName)) return getScriptParentField(varName);
            if (isScriptParentField('get_$varName')) return getScriptParentField('get_$varName')();
        }

        return resolve(varName);
    }

    private inline function isScriptParentField(field:String):Bool {
        return scriptParentFields.exists(field);
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

@:analyzer(optimize, local_dce, fusion, user_var_fusion)
class Interp extends ScriptRuntime {
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

    private function interpExpr(expr:Expr):Dynamic {
        if (expr == null) return null;

        this.lineNumber = expr.line;
        return switch (expr.expr) {
            case EMeta(name, args, expr): interpExpr(expr);
            case EConst(const): StaticInterp.evaluateConst(const);
            case EIdent(name): if (variablesDeclared[name]) variablesValues[name].r; else resolveGlobal(name);
            case EVar(name, init, isPublic, isStatic):
                if (depth == 0) {
                    var varName:String = variableNames[name];
                    if (isStatic && !StaticInterp.staticVariables.exists(varName)) {
                        StaticInterp.staticVariables.set(varName, interpExpr(init));
                        return null;
                    }
                    if (isPublic && publicVariables != null) {
                        publicVariables.set(varName, interpExpr(init));
                        return null;
                    }
                }
                declare(name, init == null ? null : interpExpr(init));
                return null;
            case EBinop(op, left, right): 
                switch (op) {
                    case ADD_ASSIGN | SUB_ASSIGN | MULT_ASSIGN | DIV_ASSIGN | MOD_ASSIGN | SHL_ASSIGN | SHR_ASSIGN | USHR_ASSIGN | OR_ASSIGN | AND_ASSIGN | XOR_ASSIGN: assignExprOp(op, left, right);
                    case NCOAL_ASSIGN: 
                        trace(left.expr, right.expr);
                        assignExprOp(op, left, right);
                    case ASSIGN: assignExpr(left, right);

                    case ADD: return interpExpr(left) + interpExpr(right);
                    case SUB: return interpExpr(left) - interpExpr(right);
                    case MULT: return interpExpr(left) * interpExpr(right);
                    case DIV: return interpExpr(left) / interpExpr(right);
                    case MOD: return interpExpr(left) % interpExpr(right);

                    case AND: return interpExpr(left) & interpExpr(right);
                    case OR: return interpExpr(left) | interpExpr(right);
                    case XOR: return interpExpr(left) ^ interpExpr(right);
                    case SHL: return interpExpr(left) << interpExpr(right);
                    case SHR: return interpExpr(left) >> interpExpr(right);
                    case USHR: return interpExpr(left) >>> interpExpr(right);

                    case EQ: return interpExpr(left) == interpExpr(right);
                    case NEQ: return interpExpr(left) != interpExpr(right);
                    case GTE: return interpExpr(left) >= interpExpr(right);
                    case LTE: return interpExpr(left) <= interpExpr(right);
                    case GT: return interpExpr(left) > interpExpr(right);
                    case LT: return interpExpr(left) < interpExpr(right);

                    case BOR: return interpExpr(left) || interpExpr(right);
                    case BAND: return interpExpr(left) && interpExpr(right);
                    case IS: return Std.isOfType(interpExpr(left), interpExpr(right));
                    case NCOAL: return interpExpr(left) ?? interpExpr(right);

                    case INTERVAL: return new IntIterator(interpExpr(left), interpExpr(right));
                    case ARROW: return null;
                }
            case EParent(expr): interpExpr(expr);
            case EBlock(exprs):
                var old:Int = store();
                var value:Dynamic = null;
                for (expr in exprs) 
                    value = interpExpr(expr);
                restore(old);
                return value;
            case EField(expr, field, isSafe): 
            	var obj:Dynamic = interpExpr(expr);
				if (isSafe && obj == null) return null;
				return StaticInterp.getObjectField(obj, field);
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
                            if (isSafe) return null;
                            error(EInvalidAccess(field), expr.line);
                            return null;
                        }
                        return StaticInterp.callObjectField(object, StaticInterp.getObjectField(object, field), argValues);
                    default: 
                        return StaticInterp.callObjectField(null, interpExpr(func), argValues);
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
            case EMapDecl(keys, values): StaticInterp.interpMap([for (key in keys) interpExpr(key)], [for (val in values) interpExpr(val)]);
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
            case EEmpty: null;
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
            if (variablesDeclared[variableID]) return variablesValues[variableID].r;
        }

        var testClass:Either<Class<Dynamic>, Enum<Dynamic>> = StaticInterp.resolvePath(path);
        if (testClass == null) {
            var splitPathCopy:Array<String> = splitPathName.copy();
            splitPathCopy.splice(-2, 1); 

            testClass = StaticInterp.resolvePath(splitPathCopy.join("."));
            if (testClass != null && !mode.match(As(_))) variableName = splitPathCopy[splitPathCopy.length-1];
        }

        if (testClass != null) {
            var value:Dynamic = switch (testClass) {
                case Left(resolvedClass): resolvedClass;
                case Right(rawEnum): StaticInterp.resolveEnum(rawEnum);
            }

            if (variablesLookup.exists(variableName)) 
                declare(variablesLookup.get(variableName), value);

            return value;
        }

        return null;
    } 

    private function interpFunction(args:Array<Argument>, body:Expr, name:VariableType, ?isPublic:Bool, ?isStatic:Bool) {
        var capturedVariablesDeclared:Vector<Bool> = duplicate(variablesDeclared);
        var capturedVariablesValues:Vector<IVariableReference> = duplicate(variablesValues);

        var interpInstance:Interp = this;

        var argsNeeded:Int = 0;
        for (arg in args) if (!arg.opt) argsNeeded++;

        var reflectiveFunction:Dynamic = null;
        var functionRef:IVariableReference = {r: null};
        var staticFunction:Dynamic = function (inputArgs:Array<Dynamic>) {
            if ((inputArgs == null ? 0 : inputArgs.length) < argsNeeded) {
                var fixedArgs:Array<Dynamic> = [];
                var extraArgs:Int = inputArgs.length - argsNeeded;
                var position:Int = 0;

                for (arg in args) {
                    if (arg.opt) {
                        if (extraArgs > 0) {
                            fixedArgs.push(inputArgs[position++]);
                            extraArgs--;
                        } else fixedArgs.push(null);
                    } 
                    else fixedArgs.push(inputArgs[position++]);
                }

                inputArgs = fixedArgs;
            }

            for (i => input in inputArgs)
                if (input == null && args[i].value != null) 
                    inputArgs[i] = interpExpr(args[i].value);

            var oldVariablesDeclared:Vector<Bool> = interpInstance.variablesDeclared;
            var oldVariablesValues:Vector<IVariableReference> = interpInstance.variablesValues;
            var oldDepth:Int = interpInstance.depth;

            interpInstance.depth++;

            interpInstance.variablesDeclared = duplicate(capturedVariablesDeclared);
            interpInstance.variablesValues = duplicate(capturedVariablesValues);

            for (arg in 0...args.length) declare(args[arg].name, inputArgs[arg]);
            var ret:Dynamic = null;

            declareReferenced(name, functionRef); // self-recurrsion

            var old:Int = store();
            if (inTry) {
                try {
                    ret = interpReturnExpr(body);
                } catch (error:Dynamic) {
                    restore(old);
                    interpInstance.variablesDeclared = oldVariablesDeclared;
                    interpInstance.variablesValues = oldVariablesValues;
                    interpInstance.depth = oldDepth;
                    throw error;
                }
            } else {
                ret = interpReturnExpr(body);
            }

            restore(old);
            interpInstance.variablesDeclared = oldVariablesDeclared;
            interpInstance.variablesValues = oldVariablesValues;
            interpInstance.depth = oldDepth;
            return ret;
        }

        reflectiveFunction = Reflect.makeVarArgs(staticFunction);
        functionRef.r = reflectiveFunction;
        if (name != -1) {
            if (depth == 0) {
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
            declareReferenced(name, functionRef);
        }
        return reflectiveFunction;
    }

    private inline function interpTry(expr, catchVar, catchExpr):Dynamic {
        var oldTryState:Bool = inTry;
        var old:Int = store();
        
        try {
            inTry = true;
            var value:Dynamic = interpExpr(expr);
            restore(old);

            inTry = oldTryState;
            return value;
        } catch (stop:IStop) {
            inTry = oldTryState;
            throw stop;
        } catch (error:Dynamic) {
            inTry = oldTryState;
            restore(old);

            declare(catchVar, error);
            var value:Dynamic = interpExpr(catchExpr);
            restore(old);

            return value;
        }
    }

    private inline function forKeyValueLoop(key:VariableType, value:VariableType, iterator:Expr, body:Expr) {
        var old:Int = store();

        declare(key, null);
        declare(value, null);

        var iterator:KeyValueIterator<Dynamic, Dynamic> = makeKeyValueIteratorExpr(iterator);
        while (iterator.hasNext()) {
            var iteratorValue:Dynamic = iterator.next();
            declare(key, iteratorValue.key);
            declare(value, iteratorValue.value);
            if (!interpLoop(body)) break;
        }

        restore(old);
    }

    private inline function forLoop(varName:VariableType, iterator:Expr, body:Expr) {
        var old:Int = store();

        declare(varName, null);

        var iterator:Iterator<Dynamic> = makeIteratorExpr(iterator);
        while (iterator.hasNext()) {
            declare(varName, iterator.next());
            if (!interpLoop(body)) break;
        }

        restore(old);
    }

    private inline function makeIteratorExpr(expr:Expr):Iterator<Dynamic> {
        var untypedIterator:Dynamic = interpExpr(expr);
        var iterator:Iterator<Dynamic> = StaticInterp.makeIterator(untypedIterator);
        return iterator == null ? throw error(EInvalidIterator(untypedIterator), expr.line) : iterator;
    }

    private inline function makeKeyValueIteratorExpr(expr:Expr):KeyValueIterator<Dynamic, Dynamic> {
        var untypedIterator:Dynamic = interpExpr(expr);
        var iterator:KeyValueIterator<Dynamic, Dynamic> = StaticInterp.makeKeyValueIterator(untypedIterator);
        return iterator == null ? throw error(EInvalidIterator(untypedIterator), expr.line) : iterator;
    }

    private inline function whileLoop(cond:Expr, body:Expr) {
        var old:Int = store();

        while (interpExpr(cond) == true) {
            if (!interpLoop(body)) break;
        }

        restore(old);
    }

    private inline function doWhileLoop(cond:Expr, body:Expr) {
        var old:Int = store();

        do {
            if (!interpLoop(body)) break;
        } while (interpExpr(cond) == true);

        
        restore(old);
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
            for (value in switchCase.values) {
                if (interpExpr(value) == switchValue) {
                    foundMatch = true; 
                    break;
                }
            }

            if (foundMatch) {
                switchValue = interpExpr(switchCase.expr);
                break;
            }
        }

        if (!foundMatch) 
            switchValue = defaultExpr != null ? interpExpr(defaultExpr) : null;

        return switchValue;
    }

    private inline function interpNew(className:VariableType, args:Array<Dynamic>):Dynamic {
        var classType:Dynamic = if (variablesDeclared[className]) variablesValues[className].r else Type.resolveClass(variableNames[className]);
        if (classType == null) classType = resolveGlobal(className);

        var params:Array<Dynamic> = [for (arg in args) interpExpr(arg)];
        return Type.createInstance(classType, params);
    }

    private function assignExpr(left:Expr, right:Expr):Dynamic {
        var assignValue:Dynamic = interpExpr(right);
        switch (left.expr) {
            case EIdent(name): 
                var varName:String = variableNames[name];
                if (hasScriptParent && isScriptParentField(varName))
                    return setScriptParentField(varName, assignValue);
                assign(name, assignValue);
            case EField(expr, field, isSafe):
                var object:Dynamic = interpExpr(expr);
                if (isSafe && object == null) return null;
                StaticInterp.setObjectField(object, field, assignValue);

            case EArray(expr, index):
                var array:Dynamic = interpExpr(expr);
                var index:Dynamic = interpExpr(index);

                if (array is IMap) StaticInterp.setMapValue(array, index, assignValue);
                else array[index] = assignValue;
            default: 
                error(EInvalidOp(Left(ASSIGN)), left.line);
        }

        return assignValue;
    }

    private function assignExprOp(op:ExprBinop, left:Expr, right:Expr):Dynamic {
        var assignValue:Dynamic = interpExpr(right);
        switch (left.expr) {
            case EIdent(name): 
                if (variablesDeclared[name])
                    assign(name, assignValue = StaticInterp.evaluateBinop(op, interpExpr(left), assignValue));
                else {
                    var varName:String = variableNames[name];

                    if (hasScriptParent && isScriptParentField(varName)) {
                        var value:Dynamic = getScriptParentField(varName);
                        assignValue = StaticInterp.evaluateBinop(op, value, assignValue);

                        assignValue = setScriptParentField(varName, assignValue);
                        return assignValue;
                    }

                    if (StaticInterp.staticVariables.exists(varName)) {
                        var value:Dynamic = StaticInterp.staticVariables.get(varName);
                        assignValue = StaticInterp.evaluateBinop(op, value, assignValue);

                        StaticInterp.staticVariables.set(varName, assignValue);
                        return assignValue;
                    }
                    
                    if (publicVariables != null && publicVariables.exists(varName)) {
                        var value:Dynamic = publicVariables.get(varName);
                        assignValue = StaticInterp.evaluateBinop(op, value, assignValue);

                        publicVariables.set(varName, assignValue);
                        return assignValue;
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
                    assignValue = StaticInterp.evaluateBinop(op, fieldValue, assignValue);

                    StaticInterp.setObjectField(object, field, assignValue);
                }
            case EArray(expr, index):
                var array:Dynamic = interpExpr(expr);
                var index:Dynamic = interpExpr(index);

                if (array is IMap) {
                    assignValue = StaticInterp.evaluateBinop(op, StaticInterp.getMapValue(array, index), assignValue);
                    StaticInterp.setMapValue(array, index, assignValue);
                } else {
                    assignValue = StaticInterp.evaluateBinop(op, array[index], assignValue);
                    array[index] = assignValue;
                }
            default: 
                error(EInvalidOp(Left(op)), left.line);
        }

        return assignValue;
    }
}

class StaticInterp {
	public static var staticVariables:StringMap<Dynamic> = new StringMap<Dynamic>();
    
    public static inline function evaluateBinop(op:ExprBinop, val1:Dynamic, val2:Dynamic):Dynamic {
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

            case INTERVAL: return new IntIterator(val1, val2);
            case ARROW | ASSIGN: return null;
        }
    }

    public static inline function evaluateConst(const:LConst):Dynamic {
        return switch (const) {
            case LCInt(int): int;
            case LCFloat(float): float;
            case LCString(string): string;
            case LCBool(bool): bool;
            case LCNull: null;
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

    public static inline function makeIterator(value:Dynamic):Iterator<Dynamic> {
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

	public static inline function makeKeyValueIterator(value:Dynamic):KeyValueIterator<Dynamic,Dynamic> {
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

    public static inline function interpMap(keys:Array<Dynamic>, values:Array<Dynamic>):Dynamic {
        if (keys.length == 0 && values.length == 0) return new haxe.ds.Map<Dynamic, Dynamic>();

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
}

/**
 * Same description as InterpLocalsImpl, allows array access variables["a"].
 */
@:forward abstract InterpLocals(InterpLocalsImpl) {
	public function new(parent:ScriptRuntime)
		this = new InterpLocalsImpl(parent);

    @:arrayAccess public function arrayGet(key:String):Dynamic return this.get(key);
    @:arrayAccess public function arraySet(key:String, value:Dynamic) this.set(key, value);
}

/**
 * Interface to set locals inside a interp. See resolve() function to see what counts as local.
 */
class InterpLocalsImpl {
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
	public var parent:ScriptRuntime;

	public function new(parent:ScriptRuntime)
		this.parent = parent;

	public inline function set(key:String, value:Dynamic) {
        if (useDefaults) {
            defaultsValues.set(key, value);
        } else {
		    if (parent.variablesLookup != null && parent.variablesLookup.exists(key)) 
                parent.assign(parent.variablesLookup.get(key), value);
        }
	}

	public inline function get(key:String):Dynamic {
        if (useDefaults) {
            return defaultsValues.get(key);
        } else {
		    if (parent.variablesLookup != null && parent.variablesLookup.exists(key)) {
                var varID:Int = parent.variablesLookup.get(key);
                return parent.variablesDeclared[varID] ? parent.variablesValues[varID].r : null; 
            } else 
                return null;
        }
	}

	public inline function exists(key:String):Bool {
		return parent.variablesLookup != null && parent.variablesLookup.exists(key) && parent.variablesDeclared[parent.variablesLookup.get(key)];
	}
}