package;

import hscript.Ast;
import haxe.CallStack;
import hscript.Parser;
import hscript.Lexer;

class Main {
    public static function main() {
        try {
            var parser = new Parser();
            var expr = parser.parseString("#if cpp @:fun(t) trace(); #elseif DUSTIN_BUILD 3 + 3; #end");
            trace(expr);
        } catch (e:Dynamic) {
            trace(e, CallStack.toString(CallStack.exceptionStack()));
        }
    }
}
