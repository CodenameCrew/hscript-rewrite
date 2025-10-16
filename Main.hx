package;

import haxe.Timer;
import hscript.Ast.Expr;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
			function fib(n) {
				if (n <= 1) return n;
				return fib(n - 1) + fib(n - 2);
			}

			return fib(20);
        ');

        var interp = new Interp("Main.hx");

		var time:Float = Timer.stamp();
		var b = 0;
		for (i in 0...20) {
        	b += interp.execute(expr);
		}
		trace(b);
		trace(Timer.stamp()- time);
    }
}