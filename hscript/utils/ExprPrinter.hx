package hscript.utils;

import hscript.Ast;
import hscript.Lexer.LConst;
import haxe.ds.Vector;

/**
 * Heavily based off https://github.com/HaxeFoundation/hscript/blob/master/hscript/Printer.hx
 */
class ExprPrinter {
	private var str:StringBuf;
	private var depth:Int = 0;
	private var spaceChar:String = null;
	private var space(get, never):String;
	private function get_space() {
		var spaces:String = "";
		if (spaceChar != null)
			for (i in 0...depth)
				spaces += spaceChar;

		return spaces;
	}

	private var variableNames:Vector<String>;

	public function new(?space:String) {
		spaceChar = space;
	}

	private function reset() {
		this.variableNames = null;
		str = new StringBuf();
		depth = 0;
	}

	private function loadTables(info:VariableInfo) {
		variableNames = Vector.fromArrayCopy(info);
	}

	public function exprToString(e:Expr) {
		reset();

		switch (e.expr) {
			case EInfo(info, e):
				loadTables(info);
				printExpr(e);
			default:
		}
		return str.toString();
	}

	private inline function add<T>(s:T)
		str.add(s);

	private function addConst(c:LConst) {
		switch (c) {
			case LCInt(int):
				add(int);
			case LCFloat(float):
				add(float);
			case LCString(string):
				add('"');
				add(string.split('"')
					.join('\\"')
					.split("\n")
					.join("\\n")
					.split("\r")
					.join("\\r")
					.split("\t")
					.join("\\t"));
				add('"');
			case LCBool(bool):
				add(bool);
			case LCNull:
				add(null);
		}
	}

	private function printExpr(e:Expr) {
		if (e == null) {
			add("<NULL>");
			return;
		}

		switch (e.expr) {
			case EConst(c):
				addConst(c);
			case EIdent(name):
				add(variableNames[name]);
			case EVar(name, init, isPublic, isStatic):
				if (isPublic)
					add("public ");
				if (isStatic)
					add("static ");
				var varName = variableNames[name];
				add('var $varName');
				if (init != null) {
					add(" = ");
					printExpr(init);
				}
			case EParent(e):
				printExpr(e);
			case EBlock(printExprs):
				if (printExprs.length == 0) {
					add("{}");
					return;
				}
				increaseScope();
				add("{\n");
				for (e in printExprs) {
					add(space);
					printExpr(e);
					add(";\n");
				}
				decreaseScope();
				add(space);
				add("}");
			case EField(e, field, isSafe):
				printExpr(e);
				if (isSafe)
					add("?");
				add('.$field');
			case EBinop(op, left, right):
				printExpr(left);
				add(' ${binopToString(op)} ');
				printExpr(right);
			case EUnop(op, isPrefix, e):
				if (isPrefix) {
					add(unopToString(op));
					printExpr(e);
					return;
				}
				printExpr(e);
				add(unopToString(op));
			case ECall(func, args):
				if (func == null)
					printExpr(func);
				else
					switch (func.expr) {
						case EField(_), EIdent(_), EConst(_):
							printExpr(func);
						default:
							add("(");
							printExpr(func);
							add(")");
					}
				add("(");
				for (i => a in args) {
					if (i > 0)
						add(", ");
					printExpr(a);
				}
				add(")");
			case EIf(cond, thenExpr, elseExpr):
				add("if (");
				printExpr(cond);
				add(") ");
				printExpr(thenExpr);
				if (elseExpr != null) {
					add(" else ");
					printExpr(elseExpr);
				}
			case EWhile(cond, body):
				add("while (");
				printExpr(cond);
				add(") ");
				printExpr(body);
			case EDoWhile(cond, body):
				add("do ");
				printExpr(body);
				add(" while (");
				printExpr(cond);
				add(" )");
			case EFor(v, iterator, body):
				var varName = variableNames[v];
				add('for ($varName in ');
				printExpr(iterator);
				add(") ");
				printExpr(body);
			case EForKeyValue(key, value, iterator, body):
				var keyName = variableNames[key];
				var valueName = variableNames[value];
				add('for ($keyName => $valueName in ');
				printExpr(iterator);
				add(") ");
				printExpr(body);
			case EBreak:
				add("break");
			case EContinue:
				add("continue");
			case EFunction(args, body, name, isPublic, isStatic):
				if (isPublic)
					add("public ");
				if (isStatic)
					add("static ");
				add("function");
				if (name != -1)
					add(' ${variableNames[name]}');
				add("(");
				for (i => a in args) {
					if (i > 0)
						add(", ");
					if (a.opt)
						add("?");
					add(variableNames[a.name]);
				}
				add(") ");
				printExpr(body);
			case EReturn(e):
				add("return ");
				if (e != null)
					printExpr(e);
			case EArray(e, index):
				printExpr(e);
				add("[");
				printExpr(index);
				add("]");
			case EArrayDecl(items):
				add("[");
				for (i => item in items) {
					if (i > 0)
						add(", ");
					printExpr(item);
				}
				add("]");
			case EMapDecl(keys, values):
				add("[");
				for (i in 0...keys.length) {
					if (i > 0)
						add(", ");
					printExpr(keys[i]);
					add(" => ");
					printExpr(values[i]);
				}
				add("]");
			case ENew(className, args):
				add('new ${variableNames[className]}(');
				for (i => a in args) {
					if (i > 0) add(", ");
					printExpr(a);
				}
				add(")");
			case EThrow(e):
				add("throw ");
				printExpr(e);
			case ETry(e, catchVar, catchExpr):
				add("try ");
				printExpr(e);
				add(' catch (${variableNames[catchVar]}) ');
				printExpr(catchExpr);
			case EObject(fields):
				if (fields.length == 0) {
					add("{}");
					return;
				}
				increaseScope();
				add("{\n");
				for (f in fields) {
					add(space);
					add('${f.name}:');
					printExpr(f.expr);
					add(",\n");
				}
				decreaseScope();
				add(space);
				add("}");
			case ETernary(cond, thenExpr, elseExpr):
				printExpr(cond);
				add(" ? ");
				printExpr(thenExpr);
				add(" : ");
				printExpr(elseExpr);
			case ESwitch(e, cases, defaultExpr):
				add("switch (");
				printExpr(e);
				add(") {");
				for (c in cases) {
					add("case ");
					for (i => v in c.values) {
						if (i > 0) add(", ");
						printExpr(v);
					}
					add(": ");
					printExpr(c.expr);
					add(";\n");
				}
				if (defaultExpr != null) {
					add("default: ");
					printExpr(defaultExpr);
					add(";\n");
				}
				add("}");
			case EMeta(name, args, e):
				add("@");
				add(name);
				if (args != null && args.length > 0) {
					add("(");
					for (i => a in args) {
						if (i > 0) add(", ");
						printExpr(a);
					}
					add(")");
				}
				add(" ");
				printExpr(e);
			case EImport(path, mode):
				add('import $path');
				switch (mode) {
					case As(name):
						add(' as $name');
					case All:
						add(".*");
					default:
				}
			case EInfo(_, _):
				add("<EInfo>");
		}
	}

	inline private function increaseScope() {depth++;}

	inline private function decreaseScope() {depth--;}

	public static inline function binopToString(op:ExprBinop):String {
		return ExprBinop.EXPR_TO_LEXER_OP.get(op);
	}

	public static inline function unopToString(op:ExprUnop):String {
		return ExprUnop.EXPR_TO_LEXER_UNOP.get(op);
	}
}
