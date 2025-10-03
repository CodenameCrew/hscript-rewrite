package;

import hscript.Ast.IHScriptCustomBehaviour;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
        function unserialize():Dynamic {
            switch (get(pos++)) {
                case 107:
                    return Math.NaN;
                case 109:
                    return Math.NEGATIVE_INFINITY;
                case 112:
                    return Math.POSITIVE_INFINITY;
                default:
            }
            pos--;
            throw "Invalid char " + fastCharAt(buf, pos) + " at position " + pos;
        }
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