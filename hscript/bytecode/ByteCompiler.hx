package hscript.bytecode;

import haxe.io.Bytes;
import haxe.ds.Vector;
import hscript.Ast;
import haxe.io.BytesOutput;
import hscript.bytecode.ByteInstruction;

enum BIntSize {
	BIInt8(int:Int);
	BIInt16(int:Int);
	BIInt32(int:Int);
}

class BInstructionPointer {
    public var position:Int;
    public var temps:Array<Int> = [];

    public function new() {}
}

class ByteCompiler {
    public var buffer:BytesOutput;

    public function new() {
        buffer = new BytesOutput();
    }

	private var variableNames:Vector<String>;
    private function loadTables(info:VariableInfo) {
		variableNames = Vector.fromArrayCopy(info);
	}

    public function compile(expr:Expr):Bytes {
        try {
            start(expr);
            return buffer.getBytes();
        } catch (e)
            return null;
    }

    public function start(expr:Expr) {
        var endPointer:BInstructionPointer = pointer();
        setreturn(endPointer);

        write(expr);

        bake(endPointer);
        unreturn();

        writePointers();
    }

    public function write(expr:Expr, used:Bool = true) {
        switch (expr.expr) {
            case EInfo(info, expr): 
                array([for (varName in info) new Expr(EConst(LCString(varName)), expr.line)]);
                buffer.writeInt8(LOAD_TABLES);

                write(expr);
            case EIdent(name):
                switch (shrink(name)) {
                    case BIInt8(_):
                        buffer.writeInt8(PUSH_MEMORY8);
                        buffer.writeInt8(name);
                    case BIInt16(_):
                        buffer.writeInt8(PUSH_MEMORY16);
                        buffer.writeInt16(name);
                    case BIInt32(_):
                        buffer.writeInt8(PUSH_MEMORY32);
                        buffer.writeInt32(name);
                }
            case EConst(c):
                switch (c) {
                    case LCInt(int):
                        if (int == 0) buffer.writeInt8(PUSH_ZERO);
                        else if (int == 1) buffer.writeInt8(PUSH_POSITIVE_ONE);
                        else if (int == -1) buffer.writeInt8(PUSH_NEGATIVE_ONE);
                        else {
                            switch (shrink(int)) {
                                case BIInt8(_):
                                    buffer.writeInt8(PUSH_INT8);
                                    buffer.writeInt8(int);
                                case BIInt16(_):
                                    buffer.writeInt8(PUSH_INT16);
                                    buffer.writeInt16(int);
                                case BIInt32(_):
                                    buffer.writeInt8(PUSH_INT32);
                                    buffer.writeInt32(int);
                            }
                        }
                    case LCFloat(float):
                        if (float == Math.PI) buffer.writeInt8(PUSH_PI);
                        else if (float == Math.POSITIVE_INFINITY) buffer.writeInt8(PUSH_POSITIVE_INFINITY);
                        else if (float == Math.NEGATIVE_INFINITY) buffer.writeInt8(PUSH_NEGATIVE_INFINITY);
                        else {
                            buffer.writeInt8(PUSH_FLOAT);
                            buffer.writeFloat(float);
                        }
                    case LCString(string):
                        if (string == "") buffer.writeInt8(PUSH_EMPTY_STRING);
                        else if (string == " ") buffer.writeInt8(PUSH_SPACE_STRING);
                        else {
                            switch (shrink(string.length)) {
                                case BIInt8(_):
                                    buffer.writeInt8(PUSH_STRING8);
                                    buffer.writeInt8(string.length);
                                    buffer.writeString(string);
                                case BIInt16(_):
                                    buffer.writeInt8(PUSH_STRING16);
                                    buffer.writeInt16(string.length);
                                    buffer.writeString(string);
                                default:
                                    buffer.writeInt8(PUSH_STRING32);
                                    buffer.writeInt32(string.length);
                                    buffer.writeString(string);
                            }
                        }
                    case LCBool(bool):
                        if (bool) buffer.writeInt8(PUSH_TRUE);
                        else buffer.writeInt8(PUSH_FALSE);
                    case LCNull: buffer.writeInt8(PUSH_NULL);
                }
            case EBinop(op, left, right):
                switch (op) {
                    case ADD_ASSIGN | SUB_ASSIGN | MULT_ASSIGN | DIV_ASSIGN | MOD_ASSIGN | SHL_ASSIGN | SHR_ASSIGN | USHR_ASSIGN | OR_ASSIGN | AND_ASSIGN | XOR_ASSIGN | NCOAL_ASSIGN:
                        switch (left.expr) {
                            case EIdent(_) | EField(_) | EArray(_): write(left);
                            default:
                                buffer.writeInt8(ERROR);
                                buffer.writeInt8(INVALID_ASSIGN);

                                return;
                        }

                        write(right);

                        buffer.writeInt8(switch (op) {
                            case ADD_ASSIGN: BINOP_ADD;
                            case SUB_ASSIGN: BINOP_SUB;
                            case MULT_ASSIGN: BINOP_MULT;
                            case DIV_ASSIGN: BINOP_DIV;
                            case MOD_ASSIGN: BINOP_MOD;
                            case SHL_ASSIGN: BINOP_SHL;
                            case SHR_ASSIGN: BINOP_SHR;
                            case USHR_ASSIGN: BINOP_USHR;
                            case OR_ASSIGN: BINOP_OR;
                            case AND_ASSIGN: BINOP_AND;
                            case XOR_ASSIGN: BINOP_XOR;
                            default: BINOP_NCOAL;
                        });

                        assign(left);
                    case ASSIGN:
                        write(right); // push right to stack
                        assign(left);
                    default:
                        write(left);
                        write(right);

                        buffer.writeInt8(switch (op) {
                            case ADD: BINOP_ADD;
                            case SUB: BINOP_SUB;
                            case MULT: BINOP_MULT;
                            case DIV: BINOP_DIV;
                            case MOD: BINOP_MOD;

                            case AND: BINOP_AND;
                            case OR: BINOP_OR;
                            case XOR: BINOP_XOR;
                            case SHL: BINOP_SHL;
                            case SHR: BINOP_SHR;
                            case USHR: BINOP_USHR;

                            case EQ: BINOP_EQ;
                            case NEQ: BINOP_NEQ;
                            case GTE: BINOP_GTE;
                            case LTE: BINOP_LTE;
                            case GT: BINOP_GT;
                            case LT: BINOP_LT;

                            case BOR: BINOP_BOR;
                            case BAND: BINOP_BAND;
                            case IS: BINOP_IS;
                            case NCOAL: BINOP_NCOAL;

                            case INTERVAL: BINOP_INTERVAL;
                            default: PUSH_NULL;
                        });
                }
            case EVar(name, init, isPublic, isStatic):
                if (init != null) write(init);
                else buffer.writeInt8(PUSH_NULL);

                var type:Null<ByteRuntimeDeclareType> = null;
                if (isPublic) type = ByteRuntimeDeclareType.PUBLIC;
                if (isStatic) type = ByteRuntimeDeclareType.STATIC;

                declare(name, type);

            case EIf(cond, thenExpr, elseExpr) | ETernary(cond, thenExpr, elseExpr):
                // EIf's must return null even if the condition is not met
                var retElseExpr:Expr = elseExpr == null ? new Expr(EConst(LCNull), thenExpr.line) : elseExpr;

                var endPointer:BInstructionPointer = pointer();
                var elsePointer:BInstructionPointer = pointer();

                write(cond);

                jump(elsePointer, GOTOIFNOT);
                write(thenExpr);

                jump(endPointer);

                bake(elsePointer);
                write(retElseExpr);

                bake(endPointer);
            case EParent(expr): write(expr);
            case EBlock(exprs): 
                for (i => expr in exprs) 
                    write(expr, i == exprs.length-1);
            case EField(expr, field, isSafe):
                write(expr); // object
                write(new Expr(EConst(LCString(field)), expr.line)); // field

                if (isSafe) buffer.writeInt8(FIELD_GET_SAFE);
                else buffer.writeInt8(FIELD_GET);
            case EArray(expr, index):
                write(expr); // array
                write(index); // index

                buffer.writeInt8(ARRAY_GET);
            case EUnop(op, isPrefix, expr):
                switch (op) {
                    case INC: write(new Expr(EBinop(ADD_ASSIGN, expr, new Expr(EConst(LCInt(1)), expr.line)), expr.line));
                    case DEC: write(new Expr(EBinop(ADD_ASSIGN, expr, new Expr(EConst(LCInt(-1)), expr.line)), expr.line));
                    case NEG: 
                        write(expr);
                        buffer.writeInt8(UNOP_NEG);
                    case NEG_BIT: 
                        write(expr);
                        buffer.writeInt8(UNOP_NEG_BIT);
                    case NOT: 
                        write(expr);
                        buffer.writeInt8(UNOP_NOT);
                }
            case ECall(func, args):
                write(func);
                array(args);
                buffer.writeInt8(CALL);
            case EWhile(cond, body):
                var endPointer:BInstructionPointer = pointer();
                var condPointer:BInstructionPointer = pointer();
                
                setbreak(endPointer);
                setcontinue(condPointer);

                bake(condPointer);
                write(cond, false);

                jump(endPointer, GOTOIFNOT);
                write(body, false);
                jump(condPointer);
                bake(endPointer);

                unbreak();
                uncontinue();
            case EDoWhile(cond, body):
                var bodyPointer:BInstructionPointer = pointer();
                var endPointer:BInstructionPointer = pointer();

                setbreak(endPointer);
                setcontinue(bodyPointer);

                bake(bodyPointer);
                write(body, false);

                write(cond, false);
                jump(bodyPointer, GOTOIF);
                bake(endPointer);

                unbreak();
                uncontinue();
            case EArrayDecl(items): array(items);
            case EMapDecl(keys, values):
                if (keys.length == 0 && values.length == 0)
                    buffer.writeInt8(PUSH_MAP);
                else {
                    array(keys);
                    array(values);

                    buffer.writeInt8(MAP_STACK);
                }
            case ENew(className, args):
                write(new Expr(EIdent(className), expr.line));
                array(args);

                buffer.writeInt8(NEW);
            case EBreak:
                var breakPointer:BInstructionPointer = getbreak();
                if (breakPointer != null) jump(breakPointer);
                else {
                    buffer.writeInt8(ERROR);
                    buffer.writeInt8(INVALID_BREAK);
                }
            case EContinue:
                var continuePointer:BInstructionPointer = getcontinue();
                if (continuePointer != null) jump(continuePointer);
                else {
                    buffer.writeInt8(ERROR);
                    buffer.writeInt8(INVALID_CONTINUE);
                }
            case EReturn(expr):
                if (expr != null) write(expr);
                var returnPointer:BInstructionPointer = getreturn();
                if (returnPointer != null) jump(returnPointer, RETURN);
            case EObject(fields):
                buffer.writeInt8(PUSH_OBJECT);
                for (field in fields) {
                    write(new Expr(EConst(LCString(field.name)), field.expr.line));
                    write(field.expr);
                    buffer.writeInt8(OBJECT_SET);
                }
            case EFor(varName, iterator, body):
                var bodyPointer:BInstructionPointer = pointer();
                var endPointer:BInstructionPointer = pointer();

                write(iterator);
                buffer.writeInt8(MAKE_ITERATOR);
                buffer.writeInt8(PUSH_NULL);
                buffer.writeInt8(COMPARASION_EQ);

                jump(bodyPointer, GOTOIFNOT);

                buffer.writeInt8(ERROR);
                buffer.writeInt8(INVALID_ITERATOR);

                jump(endPointer);

                bake(bodyPointer);

                buffer.writeInt8(ITERATOR_HASNEXT);
                buffer.writeInt8(BINOP_EQ_TRUE);

                jump(endPointer, GOTOIFNOT);
                buffer.writeInt8(ITERATOR_NEXT);
                declare(varName);

                write(body, false);

                jump(bodyPointer);
                bake(endPointer);
            case EForKeyValue(key, value, iterator, body):
                var bodyPointer:BInstructionPointer = pointer();
                var endPointer:BInstructionPointer = pointer();

                write(iterator);
                buffer.writeInt8(MAKE_KEYVALUE_ITERATOR);
                buffer.writeInt8(PUSH_NULL);
                buffer.writeInt8(COMPARASION_EQ);

                jump(bodyPointer, GOTOIFNOT);

                buffer.writeInt8(ERROR);
                buffer.writeInt8(INVALID_ITERATOR);

                jump(endPointer);
                
                bake(bodyPointer);

                buffer.writeInt8(ITERATOR_HASNEXT);
                buffer.writeInt8(BINOP_EQ_TRUE);

                jump(endPointer, GOTOIFNOT);
                buffer.writeInt8(ITERATOR_KEYVALUE_NEXT);
                declare(value);
                declare(key);

                write(body, false);

                jump(bodyPointer);
                bake(endPointer);
            case ETry(expr, catchVar, catchExpr):
                var catchPointer:BInstructionPointer = pointer();
                var endPointer:BInstructionPointer = pointer();

                jump(catchPointer, TRY);

                write(expr);

                if (catchExpr != null) {
                    jump(endPointer);

                    bake(catchPointer);
                    declare(catchVar);
                    write(catchExpr);
                } else bake(catchPointer);

                bake(endPointer);
            case EThrow(expr):
                write(expr);
                buffer.writeInt8(THROW);
            case EMeta(name, args, expr): write(expr);
            case EImport(path, mode):
                switch (mode) {
                    case As(name): write(new Expr(EConst(LCString(name)), expr.line));
                    default:
                }

                write(new Expr(EConst(LCString(path)), expr.line));

                buffer.writeInt8(IMPORT);
                buffer.writeInt8(switch (mode) {
                    case Normal: 0;
                    case As(_): 1;
                    case All: 2;
                });
            case ESwitch(expr, cases, defaultExpr):
                var endPointer:BInstructionPointer = pointer();
                var casePointers:Array<BInstructionPointer> = [for (i in 0...cases.length) pointer()];

                // Jump table
                write(expr);
                for (i => switchCase in cases) {
                    for (value in switchCase.values) {
                        write(value);
                        buffer.writeInt8(COMPARASION_EQ);
                        jump(casePointers[i], GOTOIF);
                    }
                }

                if (defaultExpr != null) {
                    buffer.writeInt8(POP);
                    write(defaultExpr);
                }
                jump(endPointer);

                for (i => switchCase in cases) {
                    bake(casePointers[i]);

                    buffer.writeInt8(POP);
                    write(switchCase.expr);

                    jump(endPointer);
                }

                bake(endPointer);
            case EFunction(args, body, name, isPublic, isStatic):
                var endPointer:BInstructionPointer = pointer();

                write(new Expr(EConst(LCBool(isPublic)), expr.line));
                write(new Expr(EConst(LCBool(isStatic)), expr.line));

                for (arg in args)
                    write(new Expr(EConst(LCBool(arg.opt)), expr.line));

                for (arg in args)
                    write(new Expr(EConst(LCInt(arg.name)), expr.line));

                write(new Expr(EConst(LCInt(args.length)), expr.line));
                write(new Expr(EConst(name != -1 ? LCInt(name) : LCNull), expr.line));

                jump(endPointer, FUNC_STACK);

                write(body);

                bake(endPointer);
        }

        if (appendsOntoStack(expr) && !used) buffer.writeInt8(POP);
    }

    private inline function array(arr:Array<Expr>) {
        if (arr.length == 0)
            buffer.writeInt8(PUSH_ARRAY);
        else {
            for (i in arr) write(i);

            switch (shrink(arr.length)) {
                case BIInt8(_): 
                    buffer.writeInt8(ARRAY_STACK8);
                    buffer.writeInt8(arr.length);
                case BIInt16(_):
                    buffer.writeInt8(ARRAY_STACK16);
                    buffer.writeInt16(arr.length);
                case BIInt32(_):
                    buffer.writeInt8(ARRAY_STACK32);
                    buffer.writeInt32(arr.length);
            }
        }
    }

    private inline function assign(eqExpr:Expr) {
        switch (eqExpr.expr) { 
            case EIdent(name): 
                switch (shrink(name)) {
                    case BIInt8(_): 
                        buffer.writeInt8(SAVE_MEMORY8);
                        buffer.writeInt8(name);
                    case BIInt16(_):
                        buffer.writeInt8(SAVE_MEMORY16);
                        buffer.writeInt16(name);
                    default: 
                }
            case EField(expr, field, isSafe):
                write(expr); // object
                write(new Expr(EConst(LCString(field)), eqExpr.line)); // field

                if (isSafe) buffer.writeInt8(FIELD_SET_SAFE);
                else buffer.writeInt8(FIELD_SET);
            case EArray(expr, index):
                write(expr); // array
                write(index); // index

                buffer.writeInt8(ARRAY_SET);
            default: 
                buffer.writeInt8(ERROR);
                buffer.writeInt8(INVALID_ASSIGN);

                buffer.writeInt8(POP); // restore stack
        }
    }

    private inline function declare(name:Int, type:Null<ByteRuntimeDeclareType> = null) {
        switch (shrink(name)) {
            case BIInt8(_):
                if (type != null) {
                    buffer.writeInt8(DECLARE_TYPED_MEMORY8);
                    buffer.writeInt8(type);
                }
                else buffer.writeInt8(DECLARE_MEMORY8);

                buffer.writeInt8(name);
            case BIInt16(_):
                if (type != null) {
                    buffer.writeInt8(DECLARE_TYPED_MEMORY16);
                    buffer.writeInt8(type);
                }
                else buffer.writeInt8(DECLARE_MEMORY16);

                buffer.writeInt16(name);
            case BIInt32(_): 
                if (type != null) {
                    buffer.writeInt8(DECLARE_TYPED_MEMORY32);
                    buffer.writeInt8(type);
                }
                else buffer.writeInt8(DECLARE_MEMORY32);

                buffer.writeInt32(name);
        }
    }

    private function appendsOntoStack(expr:Expr):Bool {
        return switch (expr.expr) {
            case EInfo(_) | EVar(_) | EParent(_) | EUnop(_) | EWhile(_) | EDoWhile(_) | EBreak | EContinue | EFor(_) | EForKeyValue(_) | EThrow(_) | EMeta(_): false;
            case EIdent(_) | EConst(_) | EBlock(_) | EField(_) | EArray(_) | ECall(_) | EArrayDecl(_) | EMapDecl(_) | ENew(_) | EObject(_) | ESwitch(_) | ETry(_) | EIf(_) | EFunction(_) | EImport(_) | ETernary(_): true;
            case EReturn(expr): expr != null;
            case EBinop(op, _):
                switch (op) {
                    case ADD_ASSIGN | SUB_ASSIGN | MULT_ASSIGN | DIV_ASSIGN | MOD_ASSIGN | SHL_ASSIGN | SHR_ASSIGN | USHR_ASSIGN | OR_ASSIGN | AND_ASSIGN | XOR_ASSIGN | NCOAL_ASSIGN | ASSIGN: false;
                    default: true;
                }
        }
    }

    /**
     * Static implementation of interpLoop(expr) in Interp.hx
     * Stores pointers for expressions that need it.
     */
    private var breakPointers:Array<BInstructionPointer> = [];
    private var continuePointers:Array<BInstructionPointer> = [];
    private var returnPointers:Array<BInstructionPointer> = [];

    private inline function getbreak():Null<BInstructionPointer>
        return (breakPointers.length > 0) ? breakPointers[breakPointers.length-1] : null;
    private inline function setbreak(pointer:BInstructionPointer) breakPointers.push(pointer);
    private inline function unbreak() breakPointers.pop();

    private inline function getcontinue():Null<BInstructionPointer>
        return (continuePointers.length > 0) ? continuePointers[continuePointers.length-1] : null;
    private inline function setcontinue(pointer:BInstructionPointer) continuePointers.push(pointer);
    private inline function uncontinue() continuePointers.pop();

    private inline function getreturn():Null<BInstructionPointer> 
        return (returnPointers.length > 0) ? returnPointers[returnPointers.length-1] : null;
    private inline function setreturn(pointer:BInstructionPointer) returnPointers.push(pointer);
    private inline function unreturn() returnPointers.pop();

    private var pointers:Array<BInstructionPointer> = [];
    /**
     * Generates a pointer object that will be compiled later to point to the pointer's bufferPos with a GOTO
     */
    private inline function pointer():BInstructionPointer {
        var pointer:BInstructionPointer = new BInstructionPointer();
        pointers.push(pointer);
        return pointer;
    }

    /**
     * Cements where the pointer acuttaly points to in the byte buffer
     * @param pointer 
     */
    private inline function bake(pointer:BInstructionPointer) {
        pointer.position = buffer.length;
    }

    /**
     * Jump to a pointer!
     * @param pointer 
     */
    private inline function jump(pointer:BInstructionPointer, jumpCode:ByteInstruction = GOTO) {
        buffer.writeInt8(jumpCode);
        pointer.temps.push(buffer.length);
        buffer.writeInt32(0);
    }

    private function writePointers() {
        var bytes:Bytes = buffer.getBytes();
        
        for (pointer in pointers)
            for (temp in pointer.temps) 
                bytes.setInt32(temp, pointer.position);
        
        var newBuffer:BytesOutput = new BytesOutput();
        newBuffer.write(bytes);
        buffer = newBuffer;
    }

    private static inline function shrink(int:Int):BIntSize {
		if (int > -0x80 && int <= 0x80) // https://github.com/HaxeFoundation/haxe/blob/4.3.7/std/haxe/io/BytesOutput.hx#L92
			return BIInt8(int);
		if (int > -0x8000 && int <= 0x8000) // https://github.com/HaxeFoundation/haxe/blob/4.3.7/std/haxe/io/BytesOutput.hx#L99
			return BIInt16(int);
		return BIInt32(int);
	}
}