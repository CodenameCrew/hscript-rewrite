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
        var expr = parser.parseString('var i = 1; try {i++; throw "Some Expection"; trace("banna");} catch(e) {trace(e);}');

		var interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		// interp.execute(expr);

		trace(ExprUtils.print(expr, true));

		var comp:ByteCompilier = new ByteCompilier();
		var byteCode:Bytes = comp.compile(expr);
		trace(byteCode.toHex());

		Sys.println(BytesPrinter.print(byteCode));
    }
}