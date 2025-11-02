package;

import hscript.anaylzers.Analyzer;
import hscript.anaylzers.Inliner;
import hscript.anaylzers.Unravel;
import hscript.Error;
import hscript.Interp;
import hscript.Parser;

using hscript.utils.ExprUtils;

class Main {
    public static function main() {
        var parser = new Parser();
        parser.preprocesorValues.set("desktop", true);
        var expr = parser.parseString("
function adjustShit() {
    final options = Options.customOptions.get(parentContentPack);
    if(options.get(\"customMenus\")) {
        final state = FlxG.state;
        if(state is PlayState) {
            var restingWidth:Int = 0;
            #if mobile
            restingWidth = Math.floor(FlxG.stage.stageWidth / (FlxG.stage.stageHeight / Constants.GAME_HEIGHT));
            #else
            restingWidth = Constants.GAME_WIDTH;
            #end
        }
    }
}


		");

		expr = Analyzer.optimize(expr);
		trace(expr.print());

		var interp:Interp = new Interp("Main.hx");
		interp.errorHandler = (error:Error) -> {Sys.println(error);}
		interp.execute(expr);
    }
}