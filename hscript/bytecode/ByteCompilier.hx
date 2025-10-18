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

    public function compile(expr:Expr) {
        switch (expr.expr) {
            case EInfo(info, expr): 
                loadTables(info);

                compile(expr);

                writePointers();
                buffer.writeInt8(RETURN);
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
                            case EIdent(_) | EField(_) | EArray(_): compile(left);
                            default:
                                buffer.writeInt8(PUSH_NULL); // TODO: ERROR HANDLING
                        }

                        compile(right);

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
                        compile(right); // push right to stack
                        assign(left);
                    default:
                        compile(left);
                        compile(right);
                        buffer.writeInt8(BINOP);
                        buffer.writeInt8(cast op);
                }
            case EVar(name, init, isPublic, isStatic):
                if (init != null) compile(init);
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

                compile(cond);

                jump(elseExpr == null ? endPointer : elsePointer, GOTOIFNOT);
                compile(thenExpr);

                if (elseExpr != null) {
                    jump(endPointer, GOTO);

                    bake(elsePointer);
                    compile(elseExpr);
                }

                bake(endPointer);
            case EParent(expr): compile(expr);
            case EBlock(exprs): for (expr in exprs) compile(expr);
            case EField(expr, field, isSafe):
                compile(expr); // object
                compile(new Expr(EConst(LCString(field)), expr.line)); // field

                if (isSafe) buffer.writeInt8(FIELD_GET_SAFE);
                else buffer.writeInt8(FIELD_GET);
            case EArray(expr, index):
                compile(expr); // array
                compile(index); // index

                buffer.writeInt8(ARRAY_GET);
            case EUnop(op, isPrefix, expr):
                switch (op) {
                    case INC: compile(new Expr(EBinop(ADD_ASSIGN, expr, new Expr(EConst(LCInt(1)), expr.line)), expr.line));
                    case DEC: compile(new Expr(EBinop(ADD_ASSIGN, expr, new Expr(EConst(LCInt(-1)), expr.line)), expr.line));
                    default:
                        buffer.writeInt8(UNOP);
                        buffer.writeInt8(cast op);
                }
            case ECall(func, args):
                compile(func);
                for (arg in args) compile(arg);

                buffer.writeInt8(ARRAY_STACK8);
                switch (shrink(args.length)) {
                    case BIInt8(_): buffer.writeInt8(args.length);
                    default: for (i in 0...args.length+1) buffer.writeInt8(POP); // TODO: ERROR HANDLING
                }
                buffer.writeInt8(CALL);
            default:
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
                compile(expr); // object
                compile(new Expr(EConst(LCString(field)), eqExpr.line)); // field

                if (isSafe) buffer.writeInt8(FIELD_SET_SAFE);
                else buffer.writeInt8(FIELD_SET);
            case EArray(expr, index):
                compile(expr); // array
                compile(index); // index

                buffer.writeInt8(ARRAY_SET);
            default: 
                buffer.writeInt8(POP); // restore stack
        }
    }

    private var pointers:Array<BInstructionPointer> = [];
    /**
     * Generates a pointer object that will be compiled later to point to the pointer's bufferPos with a GOTO16
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
    private inline function jump(pointer:BInstructionPointer, jumpCode:ByteInstruction) {
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