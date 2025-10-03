package;

import hscript.Ast.IHScriptCustomBehaviour;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
            if (pixelPerfect)
                FlxG.cameras.cameraAdded.add(__onCameraAdd);
            else
                FlxG.cameras.cameraAdded.remove(__onCameraAdd);
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