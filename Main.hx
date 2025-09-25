package;

import hscript.Expr;
import haxe.CallStack;
import hscript.Parser;
import hscript.Lexer;

class Main {
    public static function main() {
        try {
            var parser = new Parser();
            var expr = parser.parseString("
            function test(cool, awesome:Int, ?b) {
                trace('hi'); v=3*4;
                switch(v) {
                    case 3: 
                    case t: trace('HI :D');
                }
            }
            
            trace(awesome);
            ");
            trace(expr);
        } catch (e:Dynamic) {
            trace(e, CallStack.toString(CallStack.exceptionStack()));
        }
    }
}
