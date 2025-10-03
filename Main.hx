package;

import hscript.Ast.IHScriptCustomBehaviour;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('

        var newWarningFont:FlxText = null;
        function postCreate() {

            FlxG.camera.flash(0xFF000000, .3);
            MusicBeatState.skipTransIn = MusicBeatState.skipTransOut = true;
        }
        ');

        var object = new Object();
        var interp = new Interp("Main.hx");
        interp.variables.set("MusicBeatState", {skipTransIn: false, skipTransOut:false});
        interp.variables.set("FlxG", {camera: {flash: (int:Int, time:Float) -> {trace(int);}}});
        trace(interp.execute(expr));
    }
}

class Object implements IHScriptCustomBehaviour {
    public var x:Float = 3;
    public function new() {}

    public function hset(name:String, value:Dynamic):Dynamic {trace(name, value); return name;};
	public function hget(name:String):Dynamic {trace(name); return name;};
}