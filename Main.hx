package;

import hscript.Ast;
import haxe.CallStack;
import hscript.Parser;
import hscript.Interp;
import hscript.Lexer;

class Main {
    public static function main() {
        try {
            var parser = new Parser();
            var expr = parser.parseString("function test(t:Int) {return 3;} test(3);");
            trace(expr);

            var interp = new Interp();
            trace(interp.execute(expr));
        } catch (e:Dynamic) {
            trace(e, CallStack.toString(CallStack.exceptionStack()));
        }
    }
}
