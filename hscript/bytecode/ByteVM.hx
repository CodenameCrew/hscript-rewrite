package hscript.bytecode;

import hscript.Interp.ScriptRuntime;
import hscript.Ast.VariableType;
import haxe.ds.StringMap;
import haxe.ds.Vector;
import hscript.Interp.IVariableReference;
import haxe.Constraints.IMap;
import hscript.utils.UnsafeBytesInput;
import hscript.Interp.StaticInterp;
import hscript.Ast.ExprUnop;
import hscript.Ast.ExprBinop;
import hscript.bytecode.ByteInstruction;
import haxe.io.Bytes;

class ByteVM extends ScriptRuntime {
	public var instructions:Array<ByteInstruction> = [];
	public var instruction_args:Array<Int> = [];

	public var constants:Array<Dynamic> = [];
	public var pointer:Int = 0;

	private var stack:Array<Dynamic>;

	public function execute(bytes:ByteChunk) {
		this.instructions = bytes.instructions;
		this.instruction_args = bytes.instruction_args;

		this.constants = bytes.constants;
		this.pointer = -1;

		this.stack = new Array<Dynamic>();

		executeinstructions(bytes.instructions.length);
	}

	public function executeinstructions(end:Int) {
		while (pointer < end) {
			execute_instruction();
		};
	}

	public function execute_instruction():Void {
		pointer++;
		switch (instructions[pointer]) {
			case ByteInstruction.PUSH_CONST: stack.push(constants[instruction_args[pointer]]);
			case ByteInstruction.PUSH_ARRAY: stack.push([]);
			case ByteInstruction.PUSH_MAP: stack.push(new haxe.ds.Map<Dynamic, Dynamic>());
			case ByteInstruction.PUSH_OBJECT: stack.push({});
			case ByteInstruction.BINOP_ADD:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left + right);
			case ByteInstruction.BINOP_SUB:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left - right);
			case ByteInstruction.BINOP_MULT:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left * right);
			case ByteInstruction.BINOP_DIV:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left / right);
			case ByteInstruction.BINOP_MOD:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left % right);
			case ByteInstruction.BINOP_AND:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left & right);
			case ByteInstruction.BINOP_OR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left | right);
			case ByteInstruction.BINOP_XOR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left ^ right);
			case ByteInstruction.BINOP_SHL:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left << right);
			case ByteInstruction.BINOP_SHR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left >> right);
			case ByteInstruction.BINOP_USHR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left >>> right);
			case ByteInstruction.BINOP_EQ:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left == right);
			case ByteInstruction.COMPARASION_EQ:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = top();

				stack.push(left == right);
			case ByteInstruction.BINOP_EQ_TRUE: stack.push(stack.pop() == true);
			case ByteInstruction.BINOP_EQ_NULL: stack.push(stack.pop() == null);
			case ByteInstruction.BINOP_NEQ:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left != right);
			case ByteInstruction.BINOP_GTE:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left >= right);
			case ByteInstruction.BINOP_LTE:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left <= right);
			case ByteInstruction.BINOP_GT:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left > right);
			case ByteInstruction.BINOP_LT:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left < right);
			case ByteInstruction.BINOP_BOR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left || right);
			case ByteInstruction.BINOP_BAND:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left && right);
			case ByteInstruction.BINOP_IS:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(Std.isOfType(left, right));
			case ByteInstruction.BINOP_NCOAL:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(left ?? right);
			case ByteInstruction.BINOP_INTERVAL:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.push(new IntIterator(left, right));
			case ByteInstruction.UNOP_NEG: stack.push(-stack.pop());
			case ByteInstruction.UNOP_NEG_BIT: stack.push(~stack.pop());
			case ByteInstruction.UNOP_NOT: stack.push(!stack.pop());

			case ByteInstruction.DECLARE_MEMORY: declare(instruction_args[pointer], stack.pop());
			case ByteInstruction.DECLARE_PUBLIC_MEMORY: 
				if (publicVariables != null) publicVariables.set(variableNames[instruction_args[pointer]], stack.pop());
				else stack.pop();
			case ByteInstruction.DECLARE_STATIC_MEMORY: 
                var varName:String = variableNames[instruction_args[pointer]];
				if (!StaticInterp.staticVariables.exists(varName)) StaticInterp.staticVariables.set(varName, stack.pop());
				else stack.pop();
			
			case ByteInstruction.PUSH_MEMORY:
				var index:Int = instruction_args[pointer];
				stack.push(if (variablesDeclared[index]) variablesValues[index].r; else resolveGlobal(index));
			
			case ByteInstruction.SAVE_MEMORY: assign(instruction_args[pointer], stack.pop());

			case ByteInstruction.GOTO: pointer = instruction_args[pointer];
			case ByteInstruction.GOTOIF: 
				var position:Int = instruction_args[pointer];
				if (stack.pop() == true) pointer = position;
			case ByteInstruction.GOTOIFNOT: 
				var position:Int = instruction_args[pointer];
				if (stack.pop() == false) pointer = position;

			case ByteInstruction.CALL:
				var args:Null<Dynamic> = stack.pop();
				var func:Null<Dynamic> = stack.pop();
				if(!Reflect.isFunction(func))
					error(ECustom("Cannot call non function"));
				else {
					var ret:Dynamic = StaticInterp.callObjectField(null, func, args);
					stack.push(ret);
				}
			case ByteInstruction.CALL_NOARG:
				var func:Null<Dynamic> = stack.pop();
				if(!Reflect.isFunction(func))
					error(ECustom("Cannot call non function"));
				else {
					var ret:Dynamic = StaticInterp.callObjectField(null, func, []);
					stack.push(ret);
				}

			case ByteInstruction.FIELD_GET:
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = stack.pop();
				stack.push(StaticInterp.getObjectField(obj, field));

			case ByteInstruction.FIELD_SET:
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = stack.pop();
				var value:Null<Dynamic> = stack.pop();
				StaticInterp.setObjectField(obj, field, value);

			case ByteInstruction.FIELD_GET_SAFE:
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = stack.pop();

				if (obj == null) stack.push(null);
				else stack.push(StaticInterp.getObjectField(obj, field));

			case ByteInstruction.FIELD_SET_SAFE:
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = stack.pop();
				var value:Null<Dynamic> = stack.pop();

				if (obj != null) StaticInterp.setObjectField(obj, field, value);

			case ByteInstruction.NEW:
				var args:Null<Dynamic> = stack.pop();
				var cls:Null<Dynamic> = stack.pop();
				stack.push(Type.createInstance(cls, args));

			case ByteInstruction.MAKE_ITERATOR: 
				var iterator:Iterator<Dynamic> = StaticInterp.makeIterator(stack.pop());
				stack.push(iterator);
			case ByteInstruction.MAKE_KEYVALUE_ITERATOR: stack.push(StaticInterp.makeKeyValueIterator(stack.pop()));
			case ByteInstruction.ITERATOR_HASNEXT: untyped stack.push(top().hasNext());
			case ByteInstruction.ITERATOR_NEXT: untyped stack.push(top().next());
			case ByteInstruction.ITERATOR_KEYVALUE_NEXT: 
				untyped {
					var iteratorValue:Dynamic = top().next();
					stack.push(iteratorValue.key);
					stack.push(iteratorValue.value);
				}
			case ByteInstruction.ARRAY_GET:
				var index:Null<Dynamic> = stack.pop();
				var array:Null<Dynamic> = stack.pop();

				if (array is IMap) stack.push(StaticInterp.getMapValue(array, index));
                else stack.push(array[index]);

			case ByteInstruction.ARRAY_SET:
				var index:Null<Dynamic> = stack.pop();
				var array:Null<Dynamic> = stack.pop();
				var value:Null<Dynamic> = stack.pop();

				if (array is IMap) StaticInterp.setMapValue(array, index, value);
                else array[index] = value;

			case ByteInstruction.OBJECT_SET:
				var value:Null<Dynamic> = stack.pop();
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = top();

				StaticInterp.setObjectField(obj, field, value);

			case ByteInstruction.ARRAY_STACK:
				var arrayLength:Int = instruction_args[pointer];
				stack.push(stack.splice(stack.length-arrayLength, arrayLength));

			case ByteInstruction.MAP_STACK:
				var values:Null<Dynamic> = stack.pop();
				var keys:Null<Dynamic> = stack.pop();

				stack.push(StaticInterp.interpMap(keys, values));
			case ByteInstruction.LOAD_TABLES: 
				loadTables(stack.pop());
                loadBaseVariables();

			case ByteInstruction.FUNC_STACK:
			case ByteInstruction.IMPORT:
			case ByteInstruction.POP: stack.pop();
			case ByteInstruction.TRY:
			case ByteInstruction.THROW:
			case ByteInstruction.RETURN:
			case ByteInstruction.ERROR:
				var code:Int = instruction_args[pointer];

				switch (code) {
					case ByteRuntimeError.INVALID_ASSIGN: throw error(EInvalidOp(Left(ASSIGN)));
					case ByteRuntimeError.INVALID_BREAK: throw error(ECustom("Invalid break"));
					case ByteRuntimeError.INVALID_CONTINUE: throw error(ECustom("Invalid continue"));
					case ByteRuntimeError.INVALID_ITERATOR: throw error(EInvalidIterator(stack.pop()));
				}

		}
	}

	private inline function top() return stack.length > 0 ? stack[stack.length-1] : null;
}