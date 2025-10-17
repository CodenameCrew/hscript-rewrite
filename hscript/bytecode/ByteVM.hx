package hscript.bytecode;

import hscript.Interp.StaticInterp;
import hscript.Ast.ExprUnop;
import hscript.Ast.ExprBinop;
import hscript.bytecode.ByteInstruction;
import haxe.io.Bytes;
import haxe.io.BytesInput;

typedef MemoryValue = Dynamic;
typedef Memory = Array<MemoryValue>;

class ByteVMState {
	public var stack:Array<Dynamic>;
	public var reader:BytesInput;

	public function new(bytes:Bytes) {
		reader = new BytesInput(bytes);
		stack = new Array<Dynamic>();
	}

	public function clone(state:ByteVMState) {}
}

/**
 * Stores the program, the state, and the memory.
 */
class ByteVM {
	/**
	 * The program to execute.
	 */
	public var bytes:Bytes;
	private var reader:BytesInput;

	private var memory:Memory;
	public var state:ByteVMState;

	public var stack:Array<Dynamic>;

	public function new(?bytes:Bytes = null) {
		if (bytes != null) load(bytes);
	}

	public function reset() {
		this.bytes = null;
		this.reader = null;
		this.memory = null;
		this.state = null;
		this.stack = null;
	}

	public function load(bytes:Bytes) {
		state = new ByteVMState(this.bytes = bytes);
		this.reader = state.reader;
		this.stack = state.stack;
		memory = new Memory();
	}

	public function execute() {
		// TODO: STORE STATE OF THREAD
		while (reader.position < bytes.length) {
			execute_instruction();
			// trace(sys.thread.Thread.current());
		};
	}

	public function execute_instruction():Void {
		var opcode:ByteInstruction = reader.readByte();
		switch (opcode) {
			case ByteInstruction.PUSH_INT8:
				stack.push(reader.readInt8());
			case ByteInstruction.PUSH_INT16:
				stack.push(reader.readInt16());
			case ByteInstruction.PUSH_INT32:
				stack.push(reader.readInt32());
			case ByteInstruction.PUSH_FLOAT:
				stack.push(reader.readDouble());
			case ByteInstruction.PUSH_STRING8:
				var len = reader.readInt8();
				stack.push(reader.readString(len));
			case ByteInstruction.PUSH_STRING16:
				var len = reader.readInt16();
				stack.push(reader.readString(len));
			case ByteInstruction.PUSH_STRING32:
				var len = reader.readInt32();
				stack.push(reader.readString(len));

			case ByteInstruction.PUSH_NULL:
				stack.push(null);
			case ByteInstruction.PUSH_TRUE:
				stack.push(true);
			case ByteInstruction.PUSH_FALSE:
				stack.push(false);
			case ByteInstruction.PUSH_OBJECT:
				stack.push({});
			case ByteInstruction.PUSH_ZERO:
				stack.push(0);
			case ByteInstruction.PUSH_POSITIVE_ONE:
				stack.push(1);
			case ByteInstruction.PUSH_NEGATIVE_ONE:
				stack.push(-1);
			case ByteInstruction.PUSH_POSITIVE_INFINITY:
				stack.push(Math.POSITIVE_INFINITY);
			case ByteInstruction.PUSH_PI:
				stack.push(Math.PI);

			case ByteInstruction.BINOP:
                var op:ExprBinop = cast reader.readInt8();
				var right:Dynamic = stack.pop();
				var left:Dynamic = stack.pop();

                switch (op) {
                    case ADD_ASSIGN | SUB_ASSIGN | MULT_ASSIGN | DIV_ASSIGN | MOD_ASSIGN | SHL_ASSIGN | 
                        SHR_ASSIGN | USHR_ASSIGN | OR_ASSIGN | AND_ASSIGN | XOR_ASSIGN | NCOAL_ASSIGN: // assignExprOp(op, left, right);
                    case ASSIGN: // assignExpr(left, right);

                    case ADD: stack.push(left + right);
                    case SUB: stack.push(left - right);
                    case MULT: stack.push(left * right);
                    case DIV: stack.push(left / right);
                    case MOD: stack.push(left % right);

                    case AND: stack.push(left & right);
                    case OR: stack.push(left | right);
                    case XOR: stack.push(left ^ right);
                    case SHL: stack.push(left << right);
                    case SHR: stack.push(left >> right);
                    case USHR: stack.push(left >>> right);

                    case EQ: stack.push(left == right);
                    case NEQ: stack.push(left != right);
                    case GTE: stack.push(left >= right);
                    case LTE: stack.push(left <= right);
                    case GT: stack.push(left > right);
                    case LT: stack.push(left < right);

                    case BOR: stack.push(left || right);
                    case BAND: stack.push(left && right);
                    case IS: stack.push(Std.isOfType(left, right));
                    case NCOAL: stack.push(left ?? right);

                    case INTERVAL: stack.push(new IntIterator(left, right));
                    case ARROW: stack.push(null);
                }

			case ByteInstruction.UNOP:
                var unop:ExprUnop = cast reader.readInt8();
                var top:Dynamic = stack.pop();
                switch (unop) {
                    case INC: stack.push(top++);
                    case DEC: stack.push(top--);
                    case NOT: stack.push(!top);
                    case NEG: stack.push(-top);
                    case NEG_BIT: stack.push(~top);
                }

			case ByteInstruction.PUSH_MEMORY8:
				var index:Int = reader.readInt8();
				stack.push(memory[index]);
			case ByteInstruction.PUSH_MEMORY16:
				var index:Int = reader.readInt16();
				stack.push(memory[index]);
			case ByteInstruction.PUSH_MEMORY24:
				var index:Int = reader.readInt24();
				stack.push(memory[index]);

			case ByteInstruction.SAVE_MEMORY8:
				var index:Int = reader.readInt8();
				memory[index] = stack.pop();
			case ByteInstruction.SAVE_MEMORY16:
				var index:Int = reader.readInt16();
				memory[index] = stack.pop();
			case ByteInstruction.SAVE_MEMORY24:
				var index:Int = reader.readInt24();
				memory[index] = stack.pop();

			case ByteInstruction.GOTO8:
				var pos = reader.readInt8();
				reader.position = pos;
			case ByteInstruction.GOTO16:
				var pos = reader.readInt16();
				reader.position = pos;
			case ByteInstruction.GOTO32:
				var pos = reader.readInt32();
				reader.position = pos;

			case ByteInstruction.CALL:
				var args = stack.pop();
				var func = stack.pop();
				if(!Reflect.isFunction(func))
					throw "Cannot call non function";

				var ret = Reflect.callMethod(null, func, args);
				stack.push(ret);

			case ByteInstruction.CALL_NOARG:
				var func = stack.pop();
				if(!Reflect.isFunction(func))
					throw "Cannot call non function";

				var ret = Reflect.callMethod(null, func, []);
				stack.push(ret);

			case ByteInstruction.FIELD_GET:
				var field = stack.pop(); // String
				var obj = stack.pop(); // Object
				stack.push(StaticInterp.getObjectField(obj, field));

			case ByteInstruction.FIELD_SET:
				var field = stack.pop(); // String
				var obj = stack.pop(); // Object
				var value = stack.pop(); // Dynamic
				StaticInterp.setObjectField(obj, field, value);

			case ByteInstruction.NEW:
				var args = stack.pop();
				var cls = stack.pop();
				stack.push(Type.createInstance(cls, args));

			case ByteInstruction.ARRAY_GET:
				var index = stack.pop();
				var array = stack.pop();
				stack.push(array[index]);
			case ByteInstruction.ARRAY_SET:
				var index = stack.pop();
				var array = stack.pop();
				var value = stack.pop();
				array[index] = value;

			// case ByteInstruction.RETURN:

			default:
				throw "Unknown opcode: " + opcode;
		}
	}
}