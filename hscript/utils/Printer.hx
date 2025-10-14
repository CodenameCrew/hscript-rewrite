package hscript.utils;

import hscript.Ast;
import hscript.Lexer.LConst;
import haxe.ds.Vector;

/**
 * Heavily based off https://github.com/HaxeFoundation/hscript/blob/master/hscript/Printer.hx
 */
class Printer {
	public static function toString(e:Expr, tab:Bool = true):String {
		return new Printer(tab ? "\t" : null).exprToString(e);
	}

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
				expr(e);
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
		}
	}

	private function expr(e:Expr) {
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
					expr(init);
				}
			case EParent(e):
				add("(");
				expr(e);
				add(")");
			case EBlock(exprs):
				if (exprs.length == 0) {
					add("{}");
					return;
				}
				increaseScope();
				add("{\n");
				for (e in exprs) {
					add(space);
					expr(e);
					add(";\n");
				}
				decreaseScope();
				add(space);
				add("}");
			case EField(e, field, isSafe):
				expr(e);
				if (isSafe)
					add("?");
				add('.$field');
			case EBinop(op, left, right):
				expr(left);
				add(' ${binopToString(op)} ');
				expr(right);
			case EUnop(op, isPrefix, e):
				if (isPrefix) {
					add(unopToString(op));
					expr(e);
					return;
				}
				expr(e);
				add(unopToString(op));
			case ECall(func, args):
				if (func == null)
					expr(func);
				else
					switch (func.expr) {
						case EField(_), EIdent(_), EConst(_):
							expr(func);
						default:
							add("(");
							expr(func);
							add(")");
					}
				add("(");
				for (i => a in args) {
					if (i > 0)
						add(", ");
					expr(a);
				}
				add(")");
			case EIf(cond, thenExpr, elseExpr):
				add("if( ");
				expr(cond);
				add(" ) ");
				expr(thenExpr);
				if (elseExpr != null) {
					add(" else ");
					expr(elseExpr);
				}
			case EWhile(cond, body):
				add("while( ");
				expr(cond);
				add(" ) ");
				expr(body);
			case EDoWhile(cond, body):
				add("do ");
				expr(body);
				add(" while ( ");
				expr(cond);
				add(" )");
			case EFor(v, iterator, body):
				var varName = variableNames[v];
				add('for( $varName in ');
				expr(iterator);
				add(" ) ");
				expr(body);
			case EForKeyValue(key, value, iterator, body):
				var keyName = variableNames[key];
				var valueName = variableNames[value];
				add('for( $keyName => $valueName in');
				expr(iterator);
				add(" ) ");
				expr(body);
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
				expr(body);
			case EReturn(e):
				add("return ");
				if (e != null)
					expr(e);
			case EArray(e, index):
				expr(e);
				add("[");
				expr(index);
				add("]");
			case EArrayDecl(items):
				add("[");
				for (i => item in items) {
					if (i > 0)
						add(", ");
					expr(item);
				}
				add("]");
			case EMapDecl(keys, values):
				add("[");
				for (i in 0...keys.length) {
					if (i > 0)
						add(", ");
					expr(keys[i]);
					add(" => ");
					expr(values[i]);
				}
				add("]");
			case ENew(className, args):
				add('new ${variableNames[className]}(');
				for (i => a in args) {
					if (i > 0) add(", ");
					expr(a);
				}
				add(")");
			case EThrow(e):
				add("throw ");
				expr(e);
			case ETry(e, catchVar, catchExpr):
				add("try ");
				expr(e);
				add(' catch( ${variableNames[catchVar]}) ');
				expr(catchExpr);
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
					expr(f.expr);
					add(",\n");
				}
				decreaseScope();
				add(space);
				add("}");
			case ETernary(cond, thenExpr, elseExpr):
				expr(cond);
				add(" ? ");
				expr(thenExpr);
				add(" : ");
				expr(elseExpr);
			case ESwitch(e, cases, defaultExpr):
				add("switch( ");
				expr(e);
				add(") {");
				for (c in cases) {
					add("case ");
					for (i => v in c.values) {
						if (i > 0) add(", ");
						expr(v);
					}
					add(": ");
					expr(c.expr);
					add(";\n");
				}
				if (defaultExpr != null) {
					add("default: ");
					expr(defaultExpr);
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
						expr(a);
					}
					add(")");
				}
				add(" ");
				expr(e);
			case EImport(path, mode):
				add('import $path');
				switch (mode) {
					case As(name):
						add(' as $name');
					case All:
						add(".*");
					default:
				}
			default:
		}
	}

	inline private function increaseScope() {depth++;}

	inline private function decreaseScope() {depth--;}

	inline private function binopToString(op:ExprBinop):String {
		return ExprBinop.binopToString(op);
	}

	inline private function unopToString(op:ExprUnop):String {
		return ExprUnop.unopToString(op);
	}
}
