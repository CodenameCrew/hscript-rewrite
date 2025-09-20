package;

import haxe.CallStack;
import hscript.Parser;
import hscript.Lexer;

class Main {
    public static function main() {
        try {
            var parser = new Parser();
            trace(parser.parseString("trace(2 + 3 * 4);"));
        } catch (e:Dynamic) {
            trace("Error: " + e);
            trace(CallStack.toString(CallStack.exceptionStack()));
        }
    }
}