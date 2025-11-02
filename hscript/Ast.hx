package hscript;

import hscript.Lexer.LexerOp;
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

class Expr {
	public var expr:ExprDef;
	public var line:Int;

    public function new(expr:ExprDef, line:Int) {
        this.expr = expr;
        this.line = line;
    }
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
    EFunction(args:Array<Argument>, body:Expr, name:VariableType, isPublic:Bool, isStatic:Bool);
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
    EEmpty;
}

class Argument {
    public var name:VariableType;
    public var opt:Bool;
    public var value:Expr;

    public function new(name:VariableType, opt:Bool = false, ?value:Expr) {
        this.name = name;
        this.opt = opt;
        this.value = value;
    }
}

class SwitchCase {
    public var values:Array<Expr>;
    public var expr:Expr;

    public function new(values:Array<Expr>, expr:Expr) {
        this.values = values;
        this.expr = expr;
    }
}

class ObjectField {
    public var name:String; 
    public var expr:Expr;

    public function new(name:String, expr:Expr) {
        this.name = name;
        this.expr = expr;
    }
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

    public static final EXPR_TO_LEXER_OP:Map<ExprBinop, LexerOp> = [
        ExprBinop.ADD => LexerOp.ADD,
        ExprBinop.SUB => LexerOp.SUB,
        ExprBinop.MULT => LexerOp.MULT,
        ExprBinop.DIV => LexerOp.DIV,
        ExprBinop.MOD => LexerOp.MOD,

        ExprBinop.AND => LexerOp.AND,
        ExprBinop.OR => LexerOp.OR,
        ExprBinop.XOR => LexerOp.XOR,
        ExprBinop.SHL => LexerOp.SHL,
        ExprBinop.SHR => LexerOp.SHR,
        ExprBinop.USHR => LexerOp.USHR,

        ExprBinop.EQ => LexerOp.EQ,
        ExprBinop.NEQ => LexerOp.NEQ,
        ExprBinop.GTE => LexerOp.GTE,
        ExprBinop.LTE => LexerOp.LTE,
        ExprBinop.GT => LexerOp.GT,
        ExprBinop.LT => LexerOp.LT,

        ExprBinop.BOR => LexerOp.BOR,
        ExprBinop.BAND => LexerOp.BAND,
        ExprBinop.IS => LexerOp.IS,
        ExprBinop.NCOAL => LexerOp.NCOAL,

        ExprBinop.INTERVAL => LexerOp.INTERVAL,
        ExprBinop.ARROW => LexerOp.ARROW,
        ExprBinop.ASSIGN => LexerOp.ASSIGN,

        ExprBinop.ADD_ASSIGN => LexerOp.ADD_ASSIGN,
        ExprBinop.SUB_ASSIGN => LexerOp.SUB_ASSIGN,
        ExprBinop.MULT_ASSIGN => LexerOp.MULT_ASSIGN,
        ExprBinop.DIV_ASSIGN => LexerOp.DIV_ASSIGN,
        ExprBinop.MOD_ASSIGN => LexerOp.MOD_ASSIGN,
        ExprBinop.SHL_ASSIGN => LexerOp.SHL_ASSIGN,
        ExprBinop.SHR_ASSIGN => LexerOp.SHR_ASSIGN,
        ExprBinop.USHR_ASSIGN => LexerOp.USHR_ASSIGN,
        ExprBinop.OR_ASSIGN => LexerOp.OR_ASSIGN,
        ExprBinop.AND_ASSIGN => LexerOp.AND_ASSIGN,
        ExprBinop.XOR_ASSIGN => LexerOp.XOR_ASSIGN,
        ExprBinop.NCOAL_ASSIGN => LexerOp.NCOAL_ASSIGN
    ];

    public static inline function isAssign(op:ExprBinop):Dynamic {
        return switch (op) {
            case ADD_ASSIGN: true;
            case SUB_ASSIGN: true;
            case MULT_ASSIGN: true;
            case DIV_ASSIGN: true;
            case MOD_ASSIGN: true;
            case SHL_ASSIGN: true;
            case SHR_ASSIGN: true;
            case USHR_ASSIGN: true;
            case OR_ASSIGN: true;
            case AND_ASSIGN: true;
            case XOR_ASSIGN: true;
            case NCOAL_ASSIGN: true;

            default: false;
        }
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

    public static final EXPR_TO_LEXER_UNOP:Map<ExprUnop, LexerOp> = [
        ExprUnop.NEG_BIT => LexerOp.NOT_BITWISE,
        ExprUnop.NOT => LexerOp.NOT,
        ExprUnop.NEG => LexerOp.SUB,
        ExprUnop.INC => LexerOp.INCREMENT,
        ExprUnop.DEC => LexerOp.DECREMENT
    ];
}

enum EImportMode {
    Normal; // import haxe.Json;
    As(name:String); // import haxe.Json as JsonUtil;
    All; // import haxe.*;
}

typedef VariableType = Int;
typedef VariableInfo = Array<String>;

interface IHScriptCustomBehaviour {
	public function hset(name:String, value:Dynamic):Dynamic;
	public function hget(name:String):Dynamic;
}