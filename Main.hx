package;

import haxe.io.Bytes;
import hscript.utils.ExprUtils;
import hscript.utils.BytesPrinter;
import hscript.bytecode.ByteCompilier;
import hscript.Error;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('for (i in 0...3) {i;i;i;} if (true) "banna"; else "apples"; false; true; var i = 2; i++; {i += 23;} i++;');

		var interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		// interp.execute(expr);

		trace(ExprUtils.print(expr, true));

		var comp:ByteCompilier = new ByteCompilier();
		var byteCode:Bytes = comp.compile(expr);
		trace(byteCode.toHex(), byteCode.length);

		Sys.println(BytesPrinter.print(byteCode));
    }
}