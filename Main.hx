package;

import hscript.Ast.IHScriptCustomBehaviour;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
            var FNF_RESOLUTION:{width:Float, height:Float} = null;
        ');

        var object = new Object();
        var interp = new Interp("Main.hx");
        interp.variables.set("importScript", (string:String) -> {});
        interp.execute(expr);
    }
}

class Object implements IHScriptCustomBehaviour {
    public var x:Float = 3;
    public function new() {}

    public function hset(name:String, value:Dynamic):Dynamic {trace(name, value); return name;};
	public function hget(name:String):Dynamic {trace(name); return name;};
}