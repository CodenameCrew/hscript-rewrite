package;

import hscript.Ast.Expr;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
		var b = null;
		var h = null;
		function f(elapsed) {
			b = () -> {
				trace(elapsed);
			}
		}
		function c(elapsed) {
			h = () -> {
				trace(elapsed);
			}
		}
		f(34);
		c(80);
		h();
		b();
        ');

        var interp = new Interp("Main.hx");
        interp.execute(expr);
    }
}