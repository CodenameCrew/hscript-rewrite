package;

import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
			if (true == false)
				trace("banna");
			trace(null);
			true = false;
        ');

        var interp = new Interp("Main.hx");
        interp.execute(expr);
    }
}