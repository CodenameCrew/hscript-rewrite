package;

import hscript.utils.Printer;
import hscript.Ast.Expr;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString("
            import some.ClassA;
            import some.ClassB as ClassC;
            import some.*;
            var a:Int = 0;

            function sum(a:Int) {
                return a + 1;    
            }
            
            a = sum(a);
            trace(a);
            var m = [1 => 'a', 2 => 'b', 3 => 'c'];
            var b = m[1];
            trace(b);
            var c = {
                aa: ':3',
                ab: function() {
                    return 10;    
                }
            };
            trace(c?.aa);
            trace(c.ab());
        ");
        trace(Printer.toString(expr));
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