package;

import hscript.Parser;
import hscript.Lexer;

class Main {
    public static function main() {
        var lex = new Lexer();
        trace(lex.tokenize("0xFFFFFFFF"));
    }
}