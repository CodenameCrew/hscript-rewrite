package;

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
			var b = ['field' => 58];

			trace('${(a == 38 ? '${b['field']}' : '$a')}');
			trace(\"${(a == 38 ? '${b['field']}' : '$a')}\");
		");


		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);
    }
}