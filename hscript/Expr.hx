package hscript;

import hscript.Lexer.LConst;

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
 * See VariableType and VariableInfo
 */
enum ExprDef {
    EConst(c:LConst);
    EIdent(name:VariableType);
    EVar(name:VariableType, ?init:Expr, ?isPublic:Bool, ?isStatic:Bool);
    EParent(expr:Expr, ?noOptimize:Bool); // ()
    EBlock(exprs:Array<Expr>); // { ... }
    EField(expr:Expr, field:String, ?safe:Bool);
    EBinop(op:EBinop, left:Expr, right:Expr);
    ECall(func:Expr, args:Array<Expr>);
    EIf(cond:Expr, thenExpr:Expr, ?elseExpr:Expr);
    EWhile(cond:Expr, body:Expr);
    EFor(varName:VariableType, iterator:Expr, body:Expr);
    EForKeyValue(key:VariableType, iterator:Expr, body:Expr, value:VariableType);
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
    EObject(fields:Array<{ name:String, expr:Expr }>);
    ETernary(cond:Expr, thenExpr:Expr, elseExpr:Expr);
    ESwitch(expr:Expr, cases:Array<{ values:Array<Expr>, body:Expr }>, ?defaultExpr:Expr);
    EDoWhile(cond:Expr, body:Expr);
    EMeta(name:String, args:Array<Expr>, expr:Expr);
    EImport(path:String, mode:EImportMode);
    EInfo(info:VariableInfo, expr:Expr);
}

typedef Argument = {
    var name:String;
    var ?opt:Bool;
    var ?value:Expr;
};

enum EBinop {
    Add; // +
    Sub; // -
    Mult; // *
    Div; // /
    Mod; // %

    And; // &
    Or; // |
    Xor; // ^
    Shl; // <<
    Shr; // >>
    Ushr; // >>>

    Eq; // ==
    Neq; // !=
    Gte; // >=
    Lte; // <=
    Gt; // >
    Lt; // <

    Bor; // ||
    Band; // &&
    Is; // is
    Ncoal; // ??

    Interval; // ...
    Arrow; // =>
    Assign; // =

    AddAssign; // +=
    SubAssign; // -=
    MultAssign; // *=
    DivAssign; // /=
    ModAssign; // %=
    ShlAssign; // <<=
    ShrAssign; // >>=
    UshrAssign; // >>>=
    OrAssign; // |=
    AndAssign; // &=
    XorAssign; // ^=
}

enum EImportMode {
    Normal; // import haxe.Json;
    As(name:String); // import haxe.Json as JsonUtil;
    All; // import haxe.*;
}

typedef VariableType = Int;
typedef VariableInfo = Array<String>;