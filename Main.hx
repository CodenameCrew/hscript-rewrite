package;

import hscript.Ast.Expr;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
            var arr:Array<Array<Float>> = [];
            arr;
        ');

        var interp = new Interp("Main.hx");
        trace(interp.execute(expr));
    }
}