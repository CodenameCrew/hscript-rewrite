package;

import hscript.Error;
import hscript.Interp;
import hscript.Parser;

using hscript.utils.ExprUtils;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString("
			function test(a:Int, b:Int) {
				trace(a);
				return a + b;
			}
		");

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);

		if (interp.variables.exists("test")) {
			var func:Dynamic = interp.variables.get("test");
			trace(func(2, 4));
			trace(Reflect.callMethod(null, func, [7, 7]), Reflect.isFunction(func));
		}
    }
}