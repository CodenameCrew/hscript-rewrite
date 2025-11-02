package;

import hscript.anaylzers.Analyzer;
import hscript.anaylzers.Inliner;
import hscript.anaylzers.Unravel;
import hscript.Error;
import hscript.Interp;
import hscript.Parser;

using hscript.utils.ExprUtils;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString("
			function test(dt) {}
			function onUpdat2(dt) {
				function b() {trace('apple');}
				trace(dt);
				return dt;
			}
				b();
			function onUpdate(dt) {
				trace(dt);
				return dt;
			}
		");

		expr = Analyzer.optimize(expr);
		trace(expr.print());

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);

		if (interp.variables.exists("onUpdate")) {
			var func:Dynamic = interp.variables.get("onUpdate");
			
			func();
			trace(Reflect.callMethod(null, func, [7]), Reflect.callMethod(null, func, []), Reflect.isFunction(func));
		}
    }
}