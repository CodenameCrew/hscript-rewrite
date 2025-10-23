package hscript.utils;

import haxe.io.Eof;
import hscript.bytecode.ByteInstruction;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Encoding;

class BytesPrinter {
    public static function print(e:Bytes):String {
		var printer:BytesPrinter = new BytesPrinter(e);
        var output:String = printer.debug();

		printer = null;
        return output;
	}

    private var input:BytesInput;

    public function new(bytes:Bytes) {
        input = new BytesInput(bytes);
    }

    public function debug():String {
	    var str:StringBuf = new StringBuf();

        try {
            while (true) {
                var pos:Int = input.position;
                var instr:ByteInstruction = cast input.readInt8();

                str.add((input.position >= 2 ? "\n" : "") + '${hex(pos,4)}: ' + printInstruction(instr));
            }
        } catch (e:Eof) {}

        str.add("\n" + '${hex(input.position,4)}: ' + "BYTES_LEN");
        return str.toString();
    }

    private function printInstruction(instr:ByteInstruction):String {
        return switch (instr) {
            case PUSH_INT8: "PUSH_INT8 " + input.readInt8();
            case PUSH_INT16: "PUSH_INT16 " + input.readInt16();
            case PUSH_INT32: "PUSH_INT32 " + input.readInt32();
            case PUSH_FLOAT: "PUSH_FLOAT " + input.readFloat();
            case PUSH_STRING8:
                var len = input.readInt8();
                var str = input.readString(len, Encoding.UTF8);
                'PUSH_STRING8 "' + str + '"';
            case PUSH_STRING16:
                var len = input.readInt16();
                var str = input.readString(len, Encoding.UTF8);
                'PUSH_STRING16 "' + str + '"';
            case PUSH_STRING32:
                var len = input.readInt32();
                var str = input.readString(len, Encoding.UTF8);
                'PUSH_STRING32 "' + str + '"';

            case PUSH_NULL: "PUSH_NULL";
            case PUSH_TRUE: "PUSH_TRUE";
            case PUSH_FALSE: "PUSH_FALSE";
            case PUSH_EMPTY_STRING: "PUSH_EMPTY_STRING";
            case PUSH_SPACE_STRING: "PUSH_SPACE_STRING";
            case PUSH_ARRAY: "PUSH_ARRAY";
            case PUSH_MAP: "PUSH_MAP";
            case PUSH_OBJECT: "PUSH_OBJECT";
            case PUSH_ZERO: "PUSH_ZERO";
            case PUSH_POSITIVE_ONE: "PUSH_POSITIVE_ONE";
            case PUSH_NEGATIVE_ONE: "PUSH_NEGATIVE_ONE";
            case PUSH_NEGATIVE_INFINITY: "PUSH_NEGATIVE_INFINITY";
            case PUSH_POSITIVE_INFINITY: "PUSH_POSITIVE_INFINITY";
            case PUSH_PI: "PUSH_PI";

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
            case BINOP_EQ_TRUE: "BINOP == true";
            case BINOP_EQ_NULL: "BINOP == null";
            case COMPARASION: "COMPARASION";
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
            case UNOP_NOT: "UNOP -";

            case PUSH_MEMORY8: "PUSH_MEMORY8 mem[" + input.readInt8() + "]";
            case PUSH_MEMORY16: "PUSH_MEMORY16 mem[" + input.readInt16() + "]";
            case PUSH_MEMORY32: "PUSH_MEMORY32 mem[" + input.readInt32() + "]";

            case SAVE_MEMORY8: "SAVE_MEMORY8 mem[" + input.readInt8() + "]";
            case SAVE_MEMORY16: "SAVE_MEMORY16 mem[" + input.readInt16() + "]";
            case SAVE_MEMORY32: "SAVE_MEMORY32 mem[" + input.readInt32() + "]";

            case SAVE_MEMORY8_PUBLIC: "SAVE_MEMORY8_PUBLIC mem[" + input.readInt8() + "]";
            case SAVE_MEMORY16_PUBLIC: "SAVE_MEMORY16_PUBLIC mem[" + input.readInt16() + "]";
            case SAVE_MEMORY32_PUBLIC: "SAVE_MEMORY32_PUBLIC mem[" + input.readInt32() + "]";

            case SAVE_MEMORY8_STATIC: "SAVE_MEMORY8_STATIC mem[" + input.readInt8() + "]";
            case SAVE_MEMORY16_STATIC: "SAVE_MEMORY16_STATIC mem[" + input.readInt16() + "]";
            case SAVE_MEMORY32_STATIC: "SAVE_MEMORY32_STATIC mem[" + input.readInt32() + "]";

            case GOTO: "GOTO " + hex(input.readInt32(), 4);
            case GOTOIF: "GOTOIF " + hex(input.readInt32(), 4);
            case GOTOIFNOT: "GOTOIFNOT " + hex(input.readInt32(), 4);

            case CALL: "CALL";
            case CALL_NOARG: "CALL_NOARG";
            case FIELD_GET: "FIELD_GET";
            case FIELD_SET: "FIELD_SET";
            case FIELD_GET_SAFE: "FIELD_GET_SAFE";
            case FIELD_SET_SAFE: "FIELD_SET_SAFE";
            case NEW: "NEW";
            case ARRAY_GET: "ARRAY_GET";
            case ARRAY_SET: "ARRAY_SET";
            case OBJECT_SET: "OBJECT_SET";

            case MAKE_ITERATOR: "MAKE_ITERATOR";
            case MAKE_KEYVALUE_ITERATOR: "MAKE_KEYVALUE_ITERATOR";
            case ITERATOR_HASNEXT: "ITERATOR_HASNEXT";
            case ITERATOR_NEXT: "ITERATOR_NEXT";
            case ITERATOR_KEYVALUE_NEXT: "ITERATOR_KEYVALUE_NEXT";

            case ARRAY_STACK8: "ARRAY_STACK8 len=" + input.readInt8();
            case ARRAY_STACK16: "ARRAY_STACK16 len=" + input.readInt16();
            case ARRAY_STACK32: "ARRAY_STACK32 len=" + input.readInt32();

            case MAP_STACK: "MAP_STACK";
            case FUNC_STACK: "FUNC_STACK end=" + hex(input.readInt32(), 4);
            case IMPORT: "IMPORT type=" + input.readInt8();

            case POP: "POP";
            case TRY: "TRY catch=" + hex(input.readInt32(), 4);
            case THROW: "THROW";
            case RETURN: "RETURN " + hex(input.readInt32(), 4);

            case ERROR: "ERROR code=" + input.readInt8();
        }
    }

    static inline function hex(i:Int, pad:Int):String {
        var s = StringTools.hex(i, pad);
        return "0x" + s.toUpperCase();
    }
}
