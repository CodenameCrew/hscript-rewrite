package;

import hscript.Ast.Expr;
import hscript.Interp;
import hscript.Parser;

class Main {
    public static function main() {
        var parser = new Parser();
        var expr = parser.parseString('
            static function newFunkinTypeText(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true) {
                trace(X);
            }
        ');

        var parser2 = new Parser();
        var expr2 = parser2.parseString('
            newFunkinTypeText(540, 490, 670, "hawk tuah", 40);

            var obj = {
            	regexMatch: (str:String, regex:EReg) -> {    
                    var matches:Array<String> = [];
                    while (regex.match(str)) {
                        matches.push(regex.matched(1));
                        str = regex.matchedRight();
                    }
                
                    return matches;
                }
            };

        ');

        var interp = new Interp("Main.hx");
        interp.execute(expr);
        var interp2 = new Interp("Main.hx");
        interp2.execute(expr2);

        // var func = StaticInterp.staticVariables.get("newFunkinTypeText");
        // func(540, 490, 670, "hawk tuah", 40);
    }
}