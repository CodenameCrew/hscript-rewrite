package;

import hscript.Interp;
import hscript.Parser;

class Main {
    public static function fib(n) {
        if (n <= 1) return n;
        return fib(n - 1) + fib(n - 2);
    }

    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString("
            function fib(n) {
                if (n <= 1) return n;
                return fib(n - 1) + fib(n - 2);

                #if !js
                    #error
                #end
            }

            fib(20);
        ");

        var interp = new Interp();
        trace(interp.execute(expr), fib(20));
    }
}