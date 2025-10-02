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
            }

            return fib(20);

            var obj = {
                tax: 2,
                banna: 'yum',
		    };
            
            obj;
        ");

        var interp = new Interp("Main.hx");
        trace(interp.execute(expr), fib(20));
    }
}