package hscript;

import hscript.Lexer.LConst;

#if cpp
typedef UInt8 = cpp.UInt8;
#elseif cs
typedef UInt8 = cs.StdTypes.UInt8;
#elseif java
typedef UInt8 = java.types.UInt8;
#else
typedef UInt8 = UInt; // fallback for JS, Python, etc.
#end

typedef Expr = {
	var expr:ExprDef;
	var min:Int;
	var max:Int;
	var line:Int;
}

/**
 * EInfo will ALWAYS be the first expr.
 * It allows us to use a array instead of a map for varaible storage
 * MUCH much faster (supported in hscript-improved with INT_VARS compilier flag, default only option here)
 * 
 * See VariableType (Int) and VariableInfo (Array<String> to store the names).
 */
enum ExprDef {
    EConst(c:LConst);
    EIdent(name:VariableType);
    EVar(name:VariableType, ?init:Expr, ?isPublic:Bool, ?isStatic:Bool);
    EParent(expr:Expr); // ()
    EBlock(exprs:Array<Expr>); // { ... }
    EField(expr:Expr, field:String, ?safe:Bool);
    EBinop(op:EBinop, left:Expr, right:Expr);
    EUnop(op:EUnop, isPrefix:Bool, expr:Expr);
    ECall(func:Expr, args:Array<Expr>);
    EIf(cond:Expr, thenExpr:Expr, ?elseExpr:Expr);
    EWhile(cond:Expr, body:Expr);
    EFor(varName:VariableType, iterator:Expr, body:Expr);
    EForKeyValue(key:VariableType, value:VariableType, iterator:Expr, body:Expr);
    EBreak;
    EContinue;
    EFunction(args:Array<Argument>, body:Expr, ?name:VariableType, ?isPublic:Bool, ?isStatic:Bool, ?isOverride:Bool);
    EReturn(?expr:Expr);
    EArray(expr:Expr, index:Expr); // arr[i]
    EMapDecl(keys:Array<Expr>, values:Array<Expr>);
    EArrayDecl(items:Array<Expr>);
    ENew(className:VariableType, args:Array<Expr>);
    EThrow(expr:Expr);
    ETry(expr:Expr, catchVar:VariableType, catchExpr:Expr);
    EObject(fields:Array<ObjectField>);
    ETernary(cond:Expr, thenExpr:Expr, elseExpr:Expr);
    ESwitch(expr:Expr, cases:Array<SwitchCase>, ?defaultExpr:Expr);
    EDoWhile(cond:Expr, body:Expr);
    EMeta(name:String, args:Array<Expr>, expr:Expr);
    EImport(path:String, mode:EImportMode);
    EInfo(info:VariableInfo, expr:Expr);
}

typedef Argument = {
    var name:VariableType;
    var ?opt:Bool;
    var ?value:Expr;
};

typedef SwitchCase = {
    var values:Array<Expr>;
    var expr:Expr;
}

typedef ObjectField = {
    var name:String; 
    var expr:Expr;
}

/**
 * Derived from haxe manual:
 * https://haxe.org/manual/expression-operators-binops.html
 */
enum abstract EBinop(UInt8) {
    var ADD:EBinop; // +
    var SUB:EBinop; // -
    var MULT:EBinop; // *
    var DIV:EBinop; // /
    var MOD:EBinop; // %

    var AND:EBinop; // &
    var OR:EBinop; // |
    var XOR:EBinop; // ^
    var SHL:EBinop; // <<
    var SHR:EBinop; // >>
    var USHR:EBinop; // >>>

    var EQ:EBinop; // ==
    var NEQ:EBinop; // !=
    var GTE:EBinop; // >=
    var LTE:EBinop; // <=
    var GT:EBinop; // >
    var LT:EBinop; // <

    var BOR:EBinop; // ||
    var BAND:EBinop; // &&
    var IS:EBinop; // is
    var NCOAL:EBinop; // ??

    var INTERVAL:EBinop; // ...
    var ARROW:EBinop; // =>
    var ASSIGN:EBinop; // =

    var ADD_ASSIGN:EBinop; // +=
    var SUB_ASSIGN:EBinop; // -=
    var MULT_ASSIGN:EBinop; // *=
    var DIV_ASSIGN:EBinop; // /=
    var MOD_ASSIGN:EBinop; // %=
    var SHL_ASSIGN:EBinop; // <<=
    var SHR_ASSIGN:EBinop; // >>=
    var USHR_ASSIGN:EBinop; // >>>=
    var OR_ASSIGN:EBinop; // |=
    var AND_ASSIGN:EBinop; // &=
    var XOR_ASSIGN:EBinop; // ^=
    var NCOAL_ASSIGN:EBinop; // ??=

    /**
     * Precedence gotten from:
     * https://haxe.org/manual/expression-operators-precedence.html
     */
    public static final OP_PRECEDENCE:Array<Array<EBinop>> = [
        [MOD],
        [MULT, DIV],
        [ADD, SUB],
        [SHL, SHR, USHR],
        [OR, AND, XOR],
        [EQ, NEQ, GT, LT, GTE, LTE],
        [INTERVAL],
        [BAND],
        [BOR],
        [
            ASSIGN, ADD_ASSIGN, SUB_ASSIGN, MULT_ASSIGN, DIV_ASSIGN, MOD_ASSIGN, NCOAL_ASSIGN,
            SHL_ASSIGN, SHR_ASSIGN, USHR_ASSIGN, OR_ASSIGN, AND_ASSIGN, XOR_ASSIGN, ARROW
        ],
        [NCOAL],
        [IS]
    ];

    public static final OP_PRECEDENCE_LOOKUP:Array<Int> = {
        var LOOKUP_MAP:Array<Int> = new Array<Int>();
        for (i in 0...OP_PRECEDENCE.length) 
            for (x in OP_PRECEDENCE[i]) LOOKUP_MAP[cast x] = i;
        LOOKUP_MAP;
    }

    /**
     * Before compound assignment is left precedence,
     * compound assignment is 9th tier
     */
    public static final OP_PRECEDENCE_RIGHT_ASSOCIATION:Array<Bool> = {
        var LOOKUP_MAP:Array<Bool> = new Array<Bool>();
		for (x in OP_PRECEDENCE[9]) 
            LOOKUP_MAP[cast x] = true;
        LOOKUP_MAP;
    }
}

/**
 * Derived from haxe manual:
 * https://haxe.org/manual/expression-operators-unops.html
 */
enum abstract EUnop(UInt8) {
    var BitwiseNegation:EUnop; // ~

    var LogicalNegation:EUnop; // !
    var ArithmeticNegation:EUnop; // -

    var Increment:EUnop; // ++
    var Decrement:EUnop; // --
}

enum EImportMode {
    Normal; // import haxe.Json;
    As(name:String); // import haxe.Json as JsonUtil;
    All; // import haxe.*;
}

typedef VariableType = Null<Int>;
typedef VariableInfo = Array<String>;