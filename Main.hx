package;

import hscript.utils.Printer;
import hscript.Ast.Expr;
import hscript.Interp;
import hscript.Parser;

class Main {
	private static inline var code:String = "
            var a:Int = 5;

            function sum(a:Int) {
                return a + 1;    
            }
            
            a = sum(a);
            trace(a);
            var m = [1 => 'a', 2 => 'b', 3 => 'c'];
            var b = m[1];
            trace(b);
            for(k => v in m) {
                trace(k + ' -> ' + v);
            }
            var c = {
                aa: ':3',
                ab: function() {
                    return 10;    
                }
            };
            trace(c?.aa);
            trace(c.ab());
        ";
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString(code);
        trace("Code: \n");
        trace(Printer.toString(expr));
        trace("Output:");
        var interp = new Interp("Main.hx");
        interp.execute(expr);
        /*
        var parser = new Parser();
        var expr = parser.parseString('
            2 + 2;
        ');

        var interp = new Interp("Main.hx");
        interp.execute(expr);
        */
    }
}