package;

import hscript.anaylzers.Unravel;
import hscript.anaylzers.ConstEval;
import hscript.Error;
import hscript.Interp;
import hscript.Parser;

using hscript.utils.ExprUtils;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString("
			var a = 4;
			var b = {field: 58};

			trace('$a ${b.field}', Math.sin(a));
			trace(Math.atan2(a, b.field));

		");

		expr = ConstEval.eval(expr);
		expr = Unravel.eval(expr);

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);
    }
}