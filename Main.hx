package;

import hscript.Ast.Expr;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
            for (member in 1...5)
                return member;
        ');

        var interp = new Interp("Main.hx");
        trace(interp.execute(expr));
    }
}