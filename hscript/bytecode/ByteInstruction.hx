package hscript.bytecode;

typedef ByteInt = Int;

@:structInit
class ByteChunk {
	public var instructions:Array<ByteInstruction> = [];
	public var instruction_args:Array<Int> = [];

	public var constants:Array<Dynamic> = [];
}

enum abstract ByteInstruction(ByteInt) from Int to Int {
	/**
	 * FOLLOWED BY 1 ARGS -
	 * Pushes the following bytes encoded as a Int to the top of the stack.
	 */
	var PUSH_CONST:ByteInstruction = 0;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes a [] to the top of the stack
	 */
	var PUSH_ARRAY:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes a new haxe.ds.Map<Dynamic, Dynamic>() to the top of the stack.
	 */
	var PUSH_MAP:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes a {} to the top of the stack
	 */
	var PUSH_OBJECT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of an addition from the last 2 values in the stack: v1 + v2;
	 */
	var BINOP_ADD:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a subtraction from the last 2 values in the stack: v1 - v2;
	 */
	var BINOP_SUB:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a multiplication from the last 2 values in the stack: v1 * v2;
	 */
	var BINOP_MULT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a division from the last 2 values in the stack: v1 / v2;
	 */
	var BINOP_DIV:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a modulus operation from the last 2 values in the stack: v1 % v2;
	 */
	var BINOP_MOD:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a bitwise AND from the last 2 values in the stack: v1 & v2;
	 */
	var BINOP_AND:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a bitwise OR from the last 2 values in the stack: v1 | v2;
	 */
	var BINOP_OR:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a bitwise XOR from the last 2 values in the stack: v1 ^ v2;
	 */
	var BINOP_XOR:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a left bit shift from the last 2 values in the stack: v1 << v2;
	 */
	var BINOP_SHL:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a signed right bit shift from the last 2 values in the stack: v1 >> v2;
	 */
	var BINOP_SHR:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of an unsigned right bit shift from the last 2 values in the stack: v1 >>> v2;
	 */
	var BINOP_USHR:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes true or false depending on whether the last 2 values in the stack are equal: v1 == v2;
	 */
	var BINOP_EQ:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Equivalent to BINOP_EQ but is non destructive to the left variable on the stack.
	 * v1 stays on the stack when v1 == v2;
	 */
	var COMPARASION_EQ:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Equivalent to BINOP_EQ with stack[stackTop] and true.
	 */
	var BINOP_EQ_TRUE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Equivalent to BINOP_EQ with stack[stackTop] and null.
	 */
	var BINOP_EQ_NULL:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes true or false depending on whether the last 2 values in the stack are not equal: v1 != v2;
	 */
	var BINOP_NEQ:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes true or false depending on whether the first value is greater than or equal to the second: v1 >= v2;
	 */
	var BINOP_GTE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes true or false depending on whether the first value is less than or equal to the second: v1 <= v2;
	 */
	var BINOP_LTE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes true or false depending on whether the first value is greater than the second: v1 > v2;
	 */
	var BINOP_GT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes true or false depending on whether the first value is less than the second: v1 < v2;
	 */
	var BINOP_LT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes true or false depending on the logical OR of the last 2 values in the stack: v1 || v2;
	 */
	var BINOP_BOR:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes true or false depending on the logical AND of the last 2 values in the stack: v1 && v2;
	 */
	var BINOP_BAND:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes true or false depending on whether the first value is of the same type as the second: v1 is v2;
	 */
	var BINOP_IS:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes the result of a null-coalescing operation from the last 2 values in the stack: v1 ?? v2;
	 * Returns v1 if not null, otherwise v2.
	 */
	var BINOP_NCOAL:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes an IntIterator value constructed from the last 2 values in the stack: v1 ... v2;
	 */
	var BINOP_INTERVAL:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes a arthemetic negation with stack[stackTop]: -v
	 */
	var UNOP_NEG:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes a bitwise negation with stack[stackTop]: ~v
	 */
	var UNOP_NEG_BIT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes a logical negation with stack[stackTop]: !v
	 */
	var UNOP_NOT:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int.
	 */
	var DECLARE_MEMORY:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int.
	 */
	var DECLARE_PUBLIC_MEMORY:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int.
	 */
	var DECLARE_STATIC_MEMORY:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int.
	 * Pushes memory[INDX] to the top of the stack.
	 */
	var PUSH_MEMORY:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int8.
	 * Saves the top of the stack to memory[INDX], popping it in the process.
	 */
	var SAVE_MEMORY:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int.
	 * Moves the byte pointer to INDX.
	 */
	var GOTO:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int.
	 * Moves the byte pointer to INDX if stack[stacktop] == true.
	 */
	var GOTOIF:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int.
	 * Moves the byte pointer to INDX if stack[stacktop] == false.
	 */
	var GOTOIFNOT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Calls stack[stacktop-1] (a function),
	 * with a array of args from stack[stacktop],
	 * return is pushed to stacktop.
	 */
	var CALL:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Calls stack[stacktop-1] (a function),
	 * return is pushed to stacktop.
	 */
	var CALL_NOARG:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Gets property from object with field.
	 * Stack [..., object, field]
	 */
	var FIELD_GET:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Sets field of object to value.
	 * Stack [..., value, object, field]
	 */
	var FIELD_SET:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Gets property from object with field (safe ?.).
	 * Stack [..., object, field]
	 */
	var FIELD_GET_SAFE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Sets field of object to value (safe ?.).
	 * Stack [..., value, object, field]
	 */
	var FIELD_SET_SAFE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Initializes a new class instance from a class type.
	 * Stack [class, args]
	 */
	var NEW:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Calls StaticInterp.makeIterator(stack[stackTop]), popping the input and pushing the result.
	 */
	var MAKE_ITERATOR:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Calls StaticInterp.makeKeyValueIterator(stack[stackTop]), popping the input and pushing the result.
	 */
	var MAKE_KEYVALUE_ITERATOR:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes stack[stackTop].hasNext() assuming stack[stackTop] is a Iterator type.
	 */
	var ITERATOR_HASNEXT:ByteInstruction;
	
	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes stack[stackTop-1].next() assuming stack[stackTop] is a Iterator type.
	 */
	var ITERATOR_NEXT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Pushes stack[stackTop-1].next() (.key, .value) assuming stack[stackTop] is a Iterator type.
	 * Stack [..., key, value]
	 */
	var ITERATOR_KEYVALUE_NEXT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Gets a value from the array at the index.
	 * Stack [..., array, index]
	 */
	var ARRAY_GET:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Sets a value in the array at the index.
	 * Stack [..., value, array, index]
	 */
	var ARRAY_SET:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Sets field of object to value (NON DESTRUCTIVE).
	 * Differs from FIELD_SET / FIELD_SET_SAFE as it leaves the object in the stack[stackTop].
	 * Stack [..., object, field, value]
	 */
	var OBJECT_SET:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * LEN: Defined by the first bytes as a Int
	 * Creates a array from stack[stackTop-LEN] to stack[stackTop] and pushes it to top (popping all values in the process)
	 */
	var ARRAY_STACK:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Creates a map with stack[stackTop-1] (keys) and stack[stackTop] (values).
	 */
	var MAP_STACK:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * Loads stack[stackTop] as the variables for the program.
	 */
	var LOAD_TABLES:ByteInstruction;

	/**
	 * FOLLOWED BY 0 ARGS -
	 * END: following bytes encoded as a Int.
	 * 
	 * Creates a reflective function with variables from the stack:
	 * Stack [..., isStatic, isPublic, (0...argcount) arg.name, (0...argcount) arg.opt, argcount, name]
	 * 
	 * Also declares the function if the depth is 0.
	 * Pushes the resulting function to stack[stackTop].
	*/
	var FUNC_STACK:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * TYPE: Defined by the first bytes as a Int8
	 * Resolves a import with stack[stackTop].
	 * 
	 * TYPE 0 - EImportMode.Normal
	 * TYPE 1 - EImportMode.As alias = stack[stackTop-1]
	 * TYPE 2 - EImportMode.All
	 */
	var IMPORT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pops top value of the stack.
	**/
	var POP:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int.
	 * Lets the runtime know a return has happened. Runtime decides to move the byte pointer to INDX (a catch block) if a expection is caught.
	 * When a expection is hit it is stored in stack[stackTop].
	**/
	var TRY:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Throws stack[stackTop].
	**/
	var THROW:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * INDX: following bytes encoded as a Int.
	 * Lets the runtime know a return has happened. Runtime decides to move the byte pointer to INDX based on context.
	**/
	var RETURN:ByteInstruction;

	/**
	 * FOLLOWED BY 1 ARGS -
	 * CODE: following bytes encoded as a Int (USE ByteRuntimeError).
	 * Throw a runtime error with the error specified under CODE in ByteRuntimeError;
	 */
	var ERROR:ByteInstruction;
}

enum abstract ByteRuntimeError(ByteInt) from ByteInt from Int to ByteInt to Int {
	/**
	 * Throws a hscript error: EInvalidOp(Left(ASSIGN)).
	 */
	var INVALID_ASSIGN:ByteRuntimeError = 0x00;

	/**
	 * Throws a hscript error: ECustom("Invalid break").
	 */
	var INVALID_BREAK:ByteRuntimeError;

	/**
	 * Throws a hscript error: ECustom("Invalid continue").
	 */
	var INVALID_CONTINUE:ByteRuntimeError;

	/**
	 * Throws a hscript error: EInvalidIterator(stack[stackTop])
	*/
	var INVALID_ITERATOR:ByteRuntimeError;
}

enum abstract ByteRuntimeDeclareType(ByteInt) from ByteInt from Int to ByteInt to Int {
	/**
	 * Points to the ScriptRuntime's variableValues.
	 */
	var LOCAL:ByteRuntimeDeclareType = 0x00;

	/**
	 * Points to the ScriptRuntime's publicVariables.
	 */
	var PUBLIC:ByteRuntimeDeclareType;

	/**
	 * Points to the StaticInterp.staticVariables.
	 */
	var STATIC:ByteRuntimeDeclareType;

}