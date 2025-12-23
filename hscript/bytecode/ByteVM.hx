package hscript.bytecode;

import haxe.ds.GenericStack;
import hscript.Interp.ScriptRuntime;
import haxe.Constraints.IMap;
import hscript.Interp.StaticInterp;
import hscript.bytecode.ByteInstruction;

class ByteVM extends ScriptRuntime {
	public var instructions:Array<ByteInstruction> = [];
	public var instruction_args:Array<Int> = [];

	public var constants:Array<Dynamic> = [];
	public var pointer:Int = 0;

	private var stack:GenericStack<Dynamic>;

	public function execute(bytes:ByteChunk) {
		this.instructions = bytes.instructions;
		this.instruction_args = bytes.instruction_args;

		this.constants = bytes.constants;
		this.pointer = -1;

		this.stack = new GenericStack<Dynamic>();

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
			case ByteInstruction.PUSH_CONST: stack.add(constants[instruction_args[pointer]]);
			case ByteInstruction.PUSH_ARRAY: stack.add([]);
			case ByteInstruction.PUSH_MAP: stack.add(new haxe.ds.Map<Dynamic, Dynamic>());
			case ByteInstruction.PUSH_OBJECT: stack.add({});
			case ByteInstruction.BINOP_ADD:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left + right);
			case ByteInstruction.BINOP_SUB:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left - right);
			case ByteInstruction.BINOP_MULT:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left * right);
			case ByteInstruction.BINOP_DIV:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left / right);
			case ByteInstruction.BINOP_MOD:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left % right);
			case ByteInstruction.BINOP_AND:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left & right);
			case ByteInstruction.BINOP_OR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left | right);
			case ByteInstruction.BINOP_XOR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left ^ right);
			case ByteInstruction.BINOP_SHL:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left << right);
			case ByteInstruction.BINOP_SHR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left >> right);
			case ByteInstruction.BINOP_USHR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left >>> right);
			case ByteInstruction.BINOP_EQ:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left == right);
			case ByteInstruction.COMPARASION_EQ:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.first();

				stack.add(left == right);
			case ByteInstruction.BINOP_EQ_TRUE: stack.add(stack.pop() == true);
			case ByteInstruction.BINOP_EQ_NULL: stack.add(stack.pop() == null);
			case ByteInstruction.BINOP_NEQ:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left != right);
			case ByteInstruction.BINOP_GTE:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left >= right);
			case ByteInstruction.BINOP_LTE:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left <= right);
			case ByteInstruction.BINOP_GT:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left > right);
			case ByteInstruction.BINOP_LT:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left < right);
			case ByteInstruction.BINOP_BOR:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left || right);
			case ByteInstruction.BINOP_BAND:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left && right);
			case ByteInstruction.BINOP_IS:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(Std.isOfType(left, right));
			case ByteInstruction.BINOP_NCOAL:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(left ?? right);
			case ByteInstruction.BINOP_INTERVAL:
				var right:Null<Dynamic> = stack.pop();
				var left:Null<Dynamic> = stack.pop();

				stack.add(new IntIterator(left, right));
			case ByteInstruction.UNOP_NEG: stack.add(-stack.pop());
			case ByteInstruction.UNOP_NEG_BIT: stack.add(~stack.pop());
			case ByteInstruction.UNOP_NOT: stack.add(!stack.pop());

			case ByteInstruction.DECLARE_MEMORY: 
				declare(instruction_args[pointer], stack.pop());
			case ByteInstruction.DECLARE_PUBLIC_MEMORY: 
				if (publicVariables != null) publicVariables.set(variableNames[instruction_args[pointer]], stack.pop());
				else stack.pop();
			case ByteInstruction.DECLARE_STATIC_MEMORY: 
                var varName:String = variableNames[instruction_args[pointer]];
				if (!StaticInterp.staticVariables.exists(varName)) StaticInterp.staticVariables.set(varName, stack.pop());
				else stack.pop();
			
			case ByteInstruction.PUSH_MEMORY:
				var index:Int = instruction_args[pointer];
				stack.add(if (variablesDeclared[index]) variablesValues[index].r; else resolveGlobal(index));
			
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
					stack.add(ret);
				}
			case ByteInstruction.CALL_NOARG:
				var func:Null<Dynamic> = stack.pop();
				if(!Reflect.isFunction(func))
					error(ECustom("Cannot call non function"));
				else {
					var ret:Dynamic = StaticInterp.callObjectField(null, func, []);
					stack.add(ret);
				}

			case ByteInstruction.FIELD_GET:
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = stack.pop();
				stack.add(StaticInterp.getObjectField(obj, field));

			case ByteInstruction.FIELD_SET:
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = stack.pop();
				var value:Null<Dynamic> = stack.pop();
				StaticInterp.setObjectField(obj, field, value);

			case ByteInstruction.FIELD_GET_SAFE:
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = stack.pop();

				if (obj == null) stack.add(null);
				else stack.add(StaticInterp.getObjectField(obj, field));

			case ByteInstruction.FIELD_SET_SAFE:
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = stack.pop();
				var value:Null<Dynamic> = stack.pop();

				if (obj != null) StaticInterp.setObjectField(obj, field, value);

			case ByteInstruction.NEW:
				var args:Null<Dynamic> = stack.pop();
				var cls:Null<Dynamic> = stack.pop();
				stack.add(Type.createInstance(cls, args));

			case ByteInstruction.MAKE_ITERATOR: 
				var iterator:Iterator<Dynamic> = StaticInterp.makeIterator(stack.pop());
				stack.add(iterator);
			case ByteInstruction.MAKE_KEYVALUE_ITERATOR: stack.add(StaticInterp.makeKeyValueIterator(stack.pop()));
			case ByteInstruction.ITERATOR_HASNEXT: untyped stack.add(stack.first().hasNext());
			case ByteInstruction.ITERATOR_NEXT: untyped stack.add(stack.first().next());
			case ByteInstruction.ITERATOR_KEYVALUE_NEXT: 
				untyped {
					var iteratorValue:Dynamic = stack.first().next();
					stack.add(iteratorValue.key);
					stack.add(iteratorValue.value);
				}
			case ByteInstruction.ARRAY_GET:
				var index:Null<Dynamic> = stack.pop();
				var array:Null<Dynamic> = stack.pop();

				if (array is IMap) stack.add(StaticInterp.getMapValue(array, index));
                else stack.add(array[index]);

			case ByteInstruction.ARRAY_SET:
				var index:Null<Dynamic> = stack.pop();
				var array:Null<Dynamic> = stack.pop();
				var value:Null<Dynamic> = stack.pop();

				if (array is IMap) StaticInterp.setMapValue(array, index, value);
                else array[index] = value;

			case ByteInstruction.OBJECT_SET:
				var value:Null<Dynamic> = stack.pop();
				var field:Null<Dynamic> = stack.pop();
				var obj:Null<Dynamic> = stack.first();

				StaticInterp.setObjectField(obj, field, value);

			case ByteInstruction.ARRAY_STACK:
				var arrayLength:Int = instruction_args[pointer];
				var array:Array<Dynamic> = [for (i in 0...arrayLength) null];

				for (i in 0...arrayLength) array[arrayLength-i-1] = stack.pop();
				stack.add(array);
			case ByteInstruction.MAP_STACK:
				var values:Null<Dynamic> = stack.pop();
				var keys:Null<Dynamic> = stack.pop();

				stack.add(StaticInterp.interpMap(keys, values));
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
}