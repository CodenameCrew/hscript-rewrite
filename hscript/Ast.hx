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
	var line:Int;
}

/**
 * EInfo will ALWAYS be the first expr.
 * It allows us to use a array instead of a map for varaible storage.
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
    EField(expr:Expr, field:String, ?isSafe:Bool);
    EBinop(op:ExprBinop, left:Expr, right:Expr);
    EUnop(op:ExprUnop, isPrefix:Bool, expr:Expr);
    ECall(func:Expr, args:Array<Expr>);
    EIf(cond:Expr, thenExpr:Expr, ?elseExpr:Expr);
    EWhile(cond:Expr, body:Expr);
    EFor(varName:VariableType, iterator:Expr, body:Expr);
    EForKeyValue(key:VariableType, value:VariableType, iterator:Expr, body:Expr);
    EBreak;
    EContinue;
    EFunction(args:Array<Argument>, body:Expr, ?name:VariableType, ?isPublic:Bool, ?isStatic:Bool);
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
enum abstract ExprBinop(UInt8) {
    var ADD:ExprBinop; // +
    var SUB:ExprBinop; // -
    var MULT:ExprBinop; // *
    var DIV:ExprBinop; // /
    var MOD:ExprBinop; // %

    var AND:ExprBinop; // &
    var OR:ExprBinop; // |
    var XOR:ExprBinop; // ^
    var SHL:ExprBinop; // <<
    var SHR:ExprBinop; // >>
    var USHR:ExprBinop; // >>>

    var EQ:ExprBinop; // ==
    var NEQ:ExprBinop; // !=
    var GTE:ExprBinop; // >=
    var LTE:ExprBinop; // <=
    var GT:ExprBinop; // >
    var LT:ExprBinop; // <

    var BOR:ExprBinop; // ||
    var BAND:ExprBinop; // &&
    var IS:ExprBinop; // is
    var NCOAL:ExprBinop; // ??

    var INTERVAL:ExprBinop; // ...
    var ARROW:ExprBinop; // =>
    var ASSIGN:ExprBinop; // =

    var ADD_ASSIGN:ExprBinop; // +=
    var SUB_ASSIGN:ExprBinop; // -=
    var MULT_ASSIGN:ExprBinop; // *=
    var DIV_ASSIGN:ExprBinop; // /=
    var MOD_ASSIGN:ExprBinop; // %=
    var SHL_ASSIGN:ExprBinop; // <<=
    var SHR_ASSIGN:ExprBinop; // >>=
    var USHR_ASSIGN:ExprBinop; // >>>=
    var OR_ASSIGN:ExprBinop; // |=
    var AND_ASSIGN:ExprBinop; // &=
    var XOR_ASSIGN:ExprBinop; // ^=
    var NCOAL_ASSIGN:ExprBinop; // ??=

    /**
     * Precedence gotten from:
     * https://haxe.org/manual/expression-operators-precedence.html
     */
    public static final OP_PRECEDENCE:Array<Array<ExprBinop>> = [
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
enum abstract ExprUnop(UInt8) {
    var NEG_BIT:ExprUnop; // ~

    var NOT:ExprUnop; // !
    var NEG:ExprUnop; // -

    var INC:ExprUnop; // ++
    var DEC:ExprUnop; // --
}

enum EImportMode {
    Normal; // import haxe.Json;
    As(name:String); // import haxe.Json as JsonUtil;
    All; // import haxe.*;
}

typedef VariableType = Null<Int>;
typedef VariableInfo = Array<String>;