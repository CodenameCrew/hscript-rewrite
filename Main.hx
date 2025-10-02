package;

import hscript.Ast.IHScriptCustomBehaviour;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
            //

            importScript("data/global_collision");
            importScript("data/global_overworld");
            importScript("data/global_saves");
            importScript("data/global_utils");
            importScript("data/global_window");

            import funkin.backend.utils.NativeAPI;
            import funkin.backend.utils.WindowUtils;
            import lime.graphics.Image;
            import hxvlc.util.Handle;
            import haxe.io.Path;

            import Type;
            import Sys;
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