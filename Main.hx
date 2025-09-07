package;

import hscript.Lexer;

class Main {
    public static function main() {
        var lex = new Lexer();
        trace(lex.tokenize("0xFFFFFFFF"));
        trace(LOp.OP_PRECEDENCE_RIGHT_LOOKUP);
    }
}