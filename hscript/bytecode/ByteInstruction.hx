package hscript.bytecode;

typedef ByteInt = Ast.UInt8;

enum abstract ByteInstruction(ByteInt) from ByteInt from Int to ByteInt to Int {
	/**
	 * FOLLOWED BY 8 BYTES -
	 * Pushes the following bytes encoded as a Int8 to the top of the stack.
	 */
	var PUSH_INT8:ByteInstruction = 0x00;

	/**
	 * FOLLOWED BY 16 BYTES -
	 * Pushes the following bytes encoded as a Int16 to the top of the stack.
	 */
	var PUSH_INT16:ByteInstruction;

	/**
	 * FOLLOWED BY 32 BYTES -
	 * Pushes the following bytes encoded as a Int32 to the top of the stack.
	 */
	var PUSH_INT32:ByteInstruction;

	/**
	 * FOLLOWED BY 32 BYTES -
	 * Pushes the following bytes encoded as a Float to the top of the stack.
	 */
	var PUSH_FLOAT:ByteInstruction;

	/**
	 * FOLLOWED BY 8 + LEN BYTES -
	 * LEN: Defined by the first byte as a Int8
	 * Pushes the following bytes encoded as a String to the top of the stack.
	 */
	var PUSH_STRING8:ByteInstruction;

	/**
	 * FOLLOWED BY 16 + LEN BYTES -
	 * LEN: Defined by the first byte as a Int16
	 * Pushes the following bytes encoded as a String to the top of the stack.
	 */
	var PUSH_STRING16:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a null to the top of the stack
	 */
	var PUSH_NULL:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a true to the top of the stack
	 */
	var PUSH_TRUE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a false to the top of the stack
	 */
	var PUSH_FALSE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a "" to the top of the stack
	 */
	var PUSH_EMPTY_STRING:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a " " to the top of the stack
	 */
	var PUSH_SPACE_STRING:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a [] to the top of the stack
	 */
	var PUSH_ARRAY:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a false to the top of the stack
	 */
	var PUSH_OBJECT:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a 0 to the top of the stack
	 */
	var PUSH_ZERO:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a 1 to the top of the stack
	 */
	var PUSH_POSITIVE_ONE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a -1 to the top of the stack
	 */
	var PUSH_NEGATIVE_ONE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a Math.NEGATIVE_INFINITY to the top of the stack
	 */
	var PUSH_NEGATIVE_INFINITY:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a Math.POSITIVE_INFINITY to the top of the stack
	 */
	var PUSH_POSITIVE_INFINITY:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pushes a Math.PI to the top of the stack
	 */
	var PUSH_PI:ByteInstruction;

	/**
	 * FOLLOWED BY 8 BYTES -
	 * ALL BINOPS (USE ExprBinop) -
	 * uses the last 2 variables in the stack to do a binop,
	 * popping both of them and pushing the result to the stack
	 */
	var BINOP:ByteInstruction; // v1 + v2

	/**
	 * FOLLOWED BY 8 BYTES -
	 * ALL UNOPS (USE ExprUnop) -
	 * uses the last 2 variables in the stack to do a binop,
	 * popping both of them and pushing the result to the stack
	 */
	var UNOP:ByteInstruction; // -v1

	/**
	 * FOLLOWED BY 8 BYTES -
	 * INDX: following bytes encoded as a Int8.
	 * Pushes memory[INDX] to the top of the stack.
	 */
	var PUSH_MEMORY8:ByteInstruction;

	/**
	 * FOLLOWED BY 16 BYTES -
	 * INDX: following bytes encoded as a Int16.
	 * Pushes memory[INDX] to the top of the stack.
	 */
	var PUSH_MEMORY16:ByteInstruction;

	/**
	 * FOLLOWED BY 8 BYTES -
	 * INDX: following bytes encoded as a Int8.
	 * Saves the top of the stack to memory[INDX], popping it in the process.
	 */
	var SAVE_MEMORY8:ByteInstruction;

	 /**
	  * FOLLOWED BY 16 BYTES -
	  * INDX: following bytes encoded as a Int16.
	  * Saves the top of the stack to memory[INDX], popping it in the process.
	  */
	var SAVE_MEMORY16:ByteInstruction;

	/**
	 * FOLLOWED BY 8 BYTES -
	 * INDX: following bytes encoded as a Int8.
	 * Saves the top of the stack to publicVariables[INDX], popping it in the process.
	 */
	var SAVE_MEMORY8_PUBLIC:ByteInstruction;

	 /**
	  * FOLLOWED BY 16 BYTES -
	  * INDX: following bytes encoded as a Int16.
	  * Saves the top of the stack to publicVariables[INDX], popping it in the process.
	  */
	var SAVE_MEMORY16_PUBLIC:ByteInstruction;

	/**
	 * FOLLOWED BY 8 BYTES -
	 * INDX: following bytes encoded as a Int8.
	 * Saves the top of the stack to staticVariables[INDX], popping it in the process.
	 */
	var SAVE_MEMORY8_STATIC:ByteInstruction;

	 /**
	  * FOLLOWED BY 16 BYTES -
	  * INDX: following bytes encoded as a Int16.
	  * Saves the top of the stack to staticVariables[INDX], popping it in the process.
	  */
	var SAVE_MEMORY16_STATIC:ByteInstruction;

	/**
	 * FOLLOWED BY 16 BYTES -
	 * INDX: following bytes encoded as a Int16.
	 * Moves the byte pointer to INDX.
	 */
	var GOTO16:ByteInstruction;

	/**
	 * FOLLOWED BY 16 BYTES -
	 * INDX: following bytes encoded as a Int16.
	 * Moves the byte pointer to INDX if stack[stacktop] == true.
	 */
	var GOTOIF16:ByteInstruction;

	/**
	 * FOLLOWED BY 16 BYTES -
	 * INDX: following bytes encoded as a Int16.
	 * Moves the byte pointer to INDX if stack[stacktop] == false.
	 */
	var GOTOIFNOT16:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Calls stack[stacktop-1] (a function),
	 * with a array of args from stack[stacktop],
	 * return is pushed to stacktop.
	 */
	var CALL:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Calls stack[stacktop-1] (a function),
	 * return is pushed to stacktop.
	 */
	var CALL_NOARG:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Gets property from object with field.
	 * Stack [..., object, field]
	 */
	var FIELD_GET:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Sets field of object to value.
	 * Stack [..., value, object, field]
	 */
	var FIELD_SET:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Gets property from object with field (safe ?.).
	 * Stack [..., object, field]
	 */
	var FIELD_GET_SAFE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Sets field of object to value (safe ?.).
	 * Stack [..., value, object, field]
	 */
	var FIELD_SET_SAFE:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Initializes a new class instance from a class type.
	 * Stack [class, args]
	 */
	var NEW:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Gets a value from the array at the index.
	 * Stack [..., array, index]
	 */
	var ARRAY_GET:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Sets a value in the array at the index.
	 * Stack [..., value, array, index]
	 */
	var ARRAY_SET:ByteInstruction;

	/**
	 * FOLLOWED BY 8 BYTES -
	 * LEN: Defined by the first bytes as a Int8
	 * Creates a array from stack[stackTop-LEN] to stack[stackTop] and pushes it to top (popping all values in the process)
	 */
	var ARRAY_STACK8:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Pops top value of the stack.
	**/
	var POP:ByteInstruction;

	/**
	 * FOLLOWED BY 0 BYTES -
	 * Returns a value from the stack.
	**/
	var RETURN:ByteInstruction;
}