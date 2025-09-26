package;

import hscript.Ast;
import haxe.CallStack;
import hscript.Parser;
import hscript.Lexer;

class Main {
    public static function main() {
        try {
            var parser = new Parser();
            var expr = parser.parseString("var map = [1 => 3, 2 => 3];");
            trace(expr);
        } catch (e:Dynamic) {
            trace(e, CallStack.toString(CallStack.exceptionStack()));
        }
    }
}
