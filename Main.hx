package;

import hscript.Expr;
import haxe.CallStack;
import hscript.Parser;
import hscript.Lexer;

class Main {
    public static function main() {
        try {
            var parser = new Parser();
            var expr = parser.parseString("public function x() {}");
            trace(expr);
        } catch (e:Dynamic) {
            trace(e, CallStack.toString(CallStack.exceptionStack()));
        }
    }
}
