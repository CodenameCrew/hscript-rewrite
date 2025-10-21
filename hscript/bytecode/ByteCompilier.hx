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

class ByteCompilier {
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

    public function write(expr:Expr) {
        switch (expr.expr) {
            case EInfo(info, expr): write(expr);
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

                        buffer.writeInt8(BINOP);
                        buffer.writeInt8(cast switch (op) {
                            case ADD_ASSIGN: ADD;
                            case SUB_ASSIGN: SUB;
                            case MULT_ASSIGN: MULT;
                            case DIV_ASSIGN: DIV;
                            case MOD_ASSIGN: MOD;
                            case SHL_ASSIGN: SHL;
                            case SHR_ASSIGN: SHR;
                            case USHR_ASSIGN: USHR;
                            case OR_ASSIGN: OR;
                            case AND_ASSIGN: AND;
                            case XOR_ASSIGN: XOR;
                            default: NCOAL; // case: NCOAL_ASSIGN
                        });

                        assign(left);
                    case ASSIGN:
                        write(right); // push right to stack
                        assign(left);
                    default:
                        write(left);
                        write(right);
                        buffer.writeInt8(BINOP);
                        buffer.writeInt8(cast op);
                }
            case EVar(name, init, isPublic, isStatic):
                if (init != null) write(init);
                else buffer.writeInt8(PUSH_NULL);

                switch (shrink(name)) {
                    case BIInt8(_):
                        if (isStatic) buffer.writeInt8(SAVE_MEMORY8_STATIC); 
                        else if (isPublic) buffer.writeInt8(SAVE_MEMORY8_PUBLIC); 
                        else buffer.writeInt8(SAVE_MEMORY8);

                        buffer.writeInt8(name);
                    case BIInt16(_):
                        if (isStatic) buffer.writeInt8(SAVE_MEMORY16_STATIC); 
                        else if (isPublic) buffer.writeInt8(SAVE_MEMORY16_PUBLIC); 
                        else buffer.writeInt8(SAVE_MEMORY16);

                        buffer.writeInt16(name);
                    case BIInt32(_): 
                        if (isStatic) buffer.writeInt8(SAVE_MEMORY32_STATIC); 
                        else if (isPublic) buffer.writeInt8(SAVE_MEMORY32_PUBLIC); 
                        else buffer.writeInt8(SAVE_MEMORY32);

                        buffer.writeInt32(name);
                }
            case EIf(cond, thenExpr, elseExpr) | ETernary(cond, thenExpr, elseExpr):
                var endPointer:BInstructionPointer = pointer();
                var elsePointer:BInstructionPointer = pointer();

                write(cond);

                jump(elseExpr == null ? endPointer : elsePointer, GOTOIFNOT);
                write(thenExpr);

                if (elseExpr != null) {
                    jump(endPointer);

                    bake(elsePointer);
                    write(elseExpr);
                }

                bake(endPointer);
            case EParent(expr): write(expr);
            case EBlock(exprs): for (expr in exprs) write(expr);
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
                    default:
                        buffer.writeInt8(UNOP);
                        buffer.writeInt8(cast op);
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
                write(cond);

                jump(endPointer, GOTOIFNOT);
                write(body);
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
                write(body);

                write(cond);
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

                buffer.writeInt8(BINOP);
                buffer.writeInt8(cast EQ);

                jump(bodyPointer, GOTOIFNOT);

                buffer.writeInt8(ERROR);
                buffer.writeInt8(INVALID_ITERATOR);

                jump(endPointer);

                bake(bodyPointer);

                buffer.writeInt8(ITERATOR_HASNEXT);
                buffer.writeInt8(PUSH_TRUE);
                buffer.writeInt8(BINOP);
                buffer.writeInt8(cast EQ);

                jump(endPointer, GOTOIFNOT);
                buffer.writeInt8(ITERATOR_NEXT);
                assign(new Expr(EIdent(varName), expr.line));

                write(body);

                jump(bodyPointer);
                bake(endPointer);
            case EForKeyValue(key, value, iterator, body):
                var bodyPointer:BInstructionPointer = pointer();
                var endPointer:BInstructionPointer = pointer();

                write(iterator);
                buffer.writeInt8(MAKE_KEYVALUE_ITERATOR);
                buffer.writeInt8(PUSH_NULL);

                buffer.writeInt8(BINOP);
                buffer.writeInt8(cast EQ);

                jump(bodyPointer, GOTOIFNOT);

                buffer.writeInt8(ERROR);
                buffer.writeInt8(INVALID_ITERATOR);

                jump(endPointer);
                
                bake(bodyPointer);

                buffer.writeInt8(ITERATOR_HASNEXT);
                buffer.writeInt8(PUSH_TRUE);
                buffer.writeInt8(BINOP);
                buffer.writeInt8(cast EQ);

                jump(endPointer, GOTOIFNOT);
                buffer.writeInt8(ITERATOR_KEYVALUE_NEXT);
                assign(new Expr(EIdent(value), expr.line));
                assign(new Expr(EIdent(key), expr.line));

                write(body);

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
                    assign(new Expr(EIdent(catchVar), expr.line));
                    write(catchExpr);
                } else bake(catchPointer);

                bake(endPointer);
            case EThrow(expr):
                write(expr);
                buffer.writeInt8(THROW);
            default:
        }
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