package hscript.utils;

import hscript.bytecode.ByteInstruction;
import hscript.bytecode.ByteInstruction.ByteChunk;

class BytesPrinter {
    public static function print(chunk:ByteChunk):String {
        var printer:BytesPrinter = new BytesPrinter(chunk);
        var output:String = printer.debug();
        printer = null;
        return output;
    }

    private var chunk:ByteChunk;

    public function new(chunk:ByteChunk) {
        this.chunk = chunk;
    }

    public function debug():String {
        var str:StringBuf = new StringBuf();

        for (i in 0...chunk.instructions.length) {
            var instr:ByteInstruction = chunk.instructions[i];
            str.add((i >= 1 ? "\n" : "") + '${hex(i,4)}: ' + printInstruction(instr, i));
        }

        str.add("\n" + '${hex(chunk.instructions.length,4)}: ' + "BYTES_LEN");
        return str.toString();
    }

    private function printInstruction(instr:ByteInstruction, instrIndex:Int):String {
        return switch (instr) {
            case PUSH_CONST: "PUSH_CONST " + chunk.constants[chunk.instruction_args[instrIndex]];
            
            case PUSH_ARRAY: "PUSH_ARRAY";
            case PUSH_MAP: "PUSH_MAP";
            case PUSH_OBJECT: "PUSH_OBJECT";

            case BINOP_ADD: "BINOP +";
            case BINOP_SUB: "BINOP -";
            case BINOP_MULT: "BINOP *";
            case BINOP_DIV: "BINOP /";
            case BINOP_MOD: "BINOP %";
            case BINOP_AND: "BINOP &";
            case BINOP_OR: "BINOP |";
            case BINOP_XOR: "BINOP ^";
            case BINOP_SHL: "BINOP <<";
            case BINOP_SHR: "BINOP >>";
            case BINOP_USHR: "BINOP >>>";

            case BINOP_EQ: "BINOP ==";
            case COMPARASION_EQ: "COMPARASION_EQ";
            case BINOP_EQ_TRUE: "BINOP == true";
            case BINOP_EQ_NULL: "BINOP == null";
            case BINOP_NEQ: "BINOP !=";
            case BINOP_GTE: "BINOP >=";
            case BINOP_LTE: "BINOP <=";
            case BINOP_GT: "BINOP >";
            case BINOP_LT: "BINOP <";
            case BINOP_BOR: "BINOP ||";
            case BINOP_BAND: "BINOP &&";
            case BINOP_IS: "BINOP is";
            case BINOP_NCOAL: "BINOP ??";
            case BINOP_INTERVAL: "BINOP ...";

            case UNOP_NEG: "UNOP -";
            case UNOP_NEG_BIT: "UNOP ~";
            case UNOP_NOT: "UNOP !";

            case DECLARE_MEMORY: "DECLARE_MEMORY mem[" + chunk.instruction_args[instrIndex] + "]";
            case DECLARE_PUBLIC_MEMORY: "DECLARE_PUBLIC_MEMORY mem[" + chunk.instruction_args[instrIndex] + "]";
            case DECLARE_STATIC_MEMORY: "DECLARE_STATIC_MEMORY mem[" + chunk.instruction_args[instrIndex] + "]";

            case PUSH_MEMORY: "PUSH_MEMORY mem[" + chunk.instruction_args[instrIndex] + "]";
            case SAVE_MEMORY: "SAVE_MEMORY mem[" + chunk.instruction_args[instrIndex] + "]";

            case GOTO: "GOTO " + hex(chunk.instruction_args[instrIndex]+1, 4);
            case GOTOIF: "GOTOIF " + hex(chunk.instruction_args[instrIndex]+1, 4);
            case GOTOIFNOT: "GOTOIFNOT " + hex(chunk.instruction_args[instrIndex]+1, 4);

            case CALL: "CALL";
            case CALL_NOARG: "CALL_NOARG";

            case FIELD_GET: "FIELD_GET";
            case FIELD_SET: "FIELD_SET";
            case FIELD_GET_SAFE: "FIELD_GET_SAFE";
            case FIELD_SET_SAFE: "FIELD_SET_SAFE";

            case NEW: "NEW";

            case MAKE_ITERATOR: "MAKE_ITERATOR";
            case MAKE_KEYVALUE_ITERATOR: "MAKE_KEYVALUE_ITERATOR";
            case ITERATOR_HASNEXT: "ITERATOR_HASNEXT";
            case ITERATOR_NEXT: "ITERATOR_NEXT";
            case ITERATOR_KEYVALUE_NEXT: "ITERATOR_KEYVALUE_NEXT";

            case ARRAY_GET: "ARRAY_GET";
            case ARRAY_SET: "ARRAY_SET";

            case OBJECT_SET: "OBJECT_SET";
            case ARRAY_STACK: "ARRAY_STACK len=" + chunk.instruction_args[instrIndex];
            case MAP_STACK: "MAP_STACK";
            case LOAD_TABLES: "LOAD_TABLES";

            case FUNC_STACK: "FUNC_STACK end=" + hex(chunk.instruction_args[instrIndex], 4);
            case IMPORT: "IMPORT type=" + chunk.instruction_args[instrIndex];
            case POP: "POP";
            case TRY: "TRY catch=" + hex(chunk.instruction_args[instrIndex], 4);
            case THROW: "THROW";
            case RETURN: "RETURN " + hex(chunk.instruction_args[instrIndex], 4);

            case ERROR: "ERROR code=" + chunk.instruction_args[instrIndex];
        }
    }

    static inline function hex(i:Int, pad:Int):String {
        var s:String = StringTools.hex(i, pad);
        return "0x" + s.toUpperCase();
    }
}