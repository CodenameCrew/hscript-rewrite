package;

import hscript.Ast.Expr;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
            2 + 2;
        ');

        var interp = new Interp("Main.hx");
        interp.execute(expr);
    }
}