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
        var expr = parser.parseString('if (3 > 4 + 3) trace("Hello World!");');

		var interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);

		trace(ExprUtils.print(expr));

		var comp:ByteCompilier = new ByteCompilier();
		comp.compile(expr);

		var byteCode:Bytes = comp.buffer.getBytes();
		trace(byteCode.toHex());

		Sys.println(BytesPrinter.print(byteCode));
    }
}