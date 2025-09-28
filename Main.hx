package;

import haxe.Timer;
import hscript.Parser;
import hscript.Interp;

class Main {
    public static function main() {
            var parser = new Parser();
            var expr = parser.parseString("
                function fib(n) {
                    if (n <= 1) return n;
                    return fib(n - 1) + fib(n - 2);
                }

                fib(20);
            ");

            var startTime:Float = Timer.stamp();
            var e:Int = 0;
            var interp = new Interp();
            for (i in 0...50) {
                e += interp.execute(expr);
            }
            trace(Timer.stamp() - startTime, e);
    }
}
