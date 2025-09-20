package;

import haxe.CallStack;
import hscript.Parser;
import hscript.Lexer;

class Main {
    public static function main() {
        try {
            var parser = new Parser();
            trace(parser.parseString("for (v in qee...h) {}"));
        } catch (e:Dynamic) {
            trace("Error: " + e);
            trace(CallStack.toString(CallStack.exceptionStack()));
        }
    }
}