package;

import hscript.bytecode.ByteVM;
import hscript.bytecode.ByteInstruction;
import haxe.io.BytesOutput;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
			if (true == false)
				trace("banna");
			trace(null);
        ');

        var interp = new Interp("Main.hx");
        interp.execute(expr);

		var vm:ByteVM = new ByteVM();

		var pushint8:BytesOutput = new BytesOutput();
		pushint8.writeByte(ByteInstruction.PUSH_INT8);
		pushint8.writeInt8(-100);

		vm.load(pushint8.getBytes());
		vm.execute();

		trace(vm.stack[0]);
    }
}