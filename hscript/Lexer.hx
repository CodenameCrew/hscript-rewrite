package hscript;

import hscript.Error.ErrorDef;
import haxe.ds.StringMap;

typedef LTokenPos = {
    var token:LToken;
    var min:Int;
    var max:Int;
    var line:Int;
}

enum LToken {
    LTOpenP; // (
    LTCloseP; // )
    LTOpenBr; // [
    LTCloseBr; // ]
    LTOpenCB; // {
    LTCloseCB; // }
    LTComma; // ,
    LTDot; // .
    LTColon; // :
    LTSemiColon; // ;
    LTQuestion; // ?

    LTOp(op:LOp);
    LTKeyWord(keyword:LKeyword);
    LTIdentifier(identifier:String);
    LTConst(const:LConst);

    LTMeta(meta:String); // @:
    LTPrepro(prepro:String); // #if 

    LTEof; // Use StringTools.isEof();
}

enum abstract LOp(String) from String to String {
    var ADD:LOp = "+";
    var SUB:LOp = "-";
    var MULT:LOp = "*";
    var DIV:LOp = "/";
    var MOD:LOp = "%";
    var AND:LOp = "&";
    var OR:LOp = "|";
    var XOR:LOp = "^";
    var SHL:LOp = "<<";
    var SHR:LOp = ">>";
    var USHR:LOp = ">>>";
    var EQ:LOp = "==";
    var NEQ:LOp = "!=";
    var GTE:LOp = ">=";
    var LTE:LOp = "<=";
    var GT:LOp = ">";
    var LT:LOp = "<";
    var BOR:LOp = "||";
    var BAND:LOp = "&&";
    var IS:LOp = "is";
    var NCOAL:LOp = "??";

    var INTERVAL:LOp = "...";
    var ARROW:LOp = "=>";

    // Not in normal haxe as operators
    var FUNCTION_ARROW:LOp = "->";
    var ASSIGN:LOp = "=";

    var ADD_ASSIGN:LOp = "+=";
    var SUB_ASSIGN:LOp = "-=";
    var MULT_ASSIGN:LOp = "*=";
    var DIV_ASSIGN:LOp = "/=";
    var MOD_ASSIGN:LOp = "%=";
    var SHL_ASSIGN:LOp = "<<=";
    var SHR_ASSIGN:LOp = ">>=";
    var USHR_ASSIGN:LOp = ">>>=";
    var OR_ASSIGN:LOp = "|=";
    var AND_ASSIGN:LOp = "&=";
    var XOR_ASSIGN:LOp = "^=";
    var NCOAL_ASSIGN:LOp = "??=";

    var COMMENT:LOp = "//";
    var COMMENT_OPEN:LOp = "/*";
    var COMMENT_CLOSE:LOp = "*/";

    /**
     * Precedence gotten from:
     * https://haxe.org/manual/expression-operators-precedence.html
     */
    public static final OP_PRECEDENCE:Array<Array<LOp>> = [
        [MOD],
        [MULT, DIV],
        [ADD, SUB],
        [SHL, SHR, USHR],
        [OR, AND, XOR],
        [EQ, NEQ, GT, LT, GTE, LTE],
        [INTERVAL],
        [BAND],
        [BOR],
        [ // compound assignment
            ASSIGN, ADD_ASSIGN, SUB_ASSIGN, MULT_ASSIGN, DIV_ASSIGN, MOD_ASSIGN, NCOAL_ASSIGN,
            SHL_ASSIGN, SHR_ASSIGN, USHR_ASSIGN, OR_ASSIGN, AND_ASSIGN, XOR_ASSIGN, ARROW
        ],
        [FUNCTION_ARROW, NCOAL],
        [IS]
    ];

    public static final OP_PRECEDENCE_LEFT_LOOKUP:StringMap<Int> = {
        var LOOKUP_MAP:StringMap<Int> = new StringMap<Int>();

        for (i in 0...9) // before compound assignment is left 
			for (x in OP_PRECEDENCE[i]) LOOKUP_MAP.set(x, i);

        LOOKUP_MAP;
    }

    public static final OP_PRECEDENCE_RIGHT_LOOKUP:StringMap<Int> = {
        var LOOKUP_MAP:StringMap<Int> = new StringMap<Int>();

        for (i in 9...OP_PRECEDENCE.length) // after compound assignment is right 
			for (x in OP_PRECEDENCE[i]) LOOKUP_MAP.set(x, i);
        
        LOOKUP_MAP;
    }
}

/**
 * Keywords gotten from:
 * https://haxe.org/manual/expression.html
 * 
 * With expections to type creation.
 */
enum abstract LKeyword(String) from String {
    var BREAK:LKeyword = "break";
    var CASE:LKeyword = "case";
    var CAST:LKeyword = "cast";
    var CATCH:LKeyword = "catch";
    var CONTINUE:LKeyword = "continue";
    var DEFAULT:LKeyword = "default";
    var DO:LKeyword = "do";
    var ELSE:LKeyword = "else";
    var FALSE:LKeyword = "false";
    var FINAL:LKeyword = "final";
    var FOR:LKeyword = "for";
    var FUNCTION:LKeyword = "function";
    var IF:LKeyword = "if";
    var IMPORT:LKeyword = "import";
    var IN:LKeyword = "in";
    var INLINE:LKeyword = "inline";
    var NEW:LKeyword = "new";
    var NULL:LKeyword = "null";
    var PRIVATE:LKeyword = "private";
    var PUBLIC:LKeyword = "public";
    var RETURN:LKeyword = "return";
    var STATIC:LKeyword = "static";
    var SWITCH:LKeyword = "switch";
    var THIS:LKeyword = "this";
    var THROW:LKeyword = "throw";
    var TRUE:LKeyword = "true";
    var TRY:LKeyword = "try";
    var VAR:LKeyword = "var";
    var WHILE:LKeyword = "while";

    public static final ALL_KEYWORDS:Array<LKeyword> = [
        BREAK, CASE, CAST, CATCH, CONTINUE, DEFAULT, DO, ELSE,
        FALSE, FINAL, FOR, FUNCTION, IF, IMPORT, IN, INLINE,
        NEW, NULL, PRIVATE, PUBLIC, RETURN, STATIC, SWITCH,
        THIS, TRUE, TRY, VAR, WHILE
    ];

    // Hashmap under the hood, faster then doing ALL_KEYWORDS.indexOf(string) != -1 (linear scan across array) -lunar
    public static final ALL_KEYWORDS_LOOKUP:StringMap<LKeyword> = {
        var LOOKUP_MAP:StringMap<LKeyword> = new StringMap<LKeyword>();

        for (keyword in ALL_KEYWORDS) 
            LOOKUP_MAP.set(Std.string(keyword), keyword);

        LOOKUP_MAP;
    }
}

enum LConst {
	LCInt(int:Int);
	LCFloat(float:Float);
	LCString(string:String);
}

/**
 * Tokenizing heavily based off https://github.com/HaxeFoundation/hscript/blob/master/hscript/Parser.hx
 */
class Lexer {
    public static final IDENTIFIER_CHARS:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_";
    public static final OPERATOR_CHARS:String = "+*/-=!><&|^%~";

    public static final IDENTIFIER_CHARS_LOOKUP:Array<Bool> = {
        var LOOKUP_ARRAY:Array<Bool> = [];

        for (i in 0...IDENTIFIER_CHARS.length)
            LOOKUP_ARRAY[IDENTIFIER_CHARS.charCodeAt(i)] = true;

        LOOKUP_ARRAY;
    };

    public static final OPERATOR_CHARS_LOOKUP:Array<Bool> = {
        var LOOKUP_ARRAY:Array<Bool> = [];

        for (i in 0...OPERATOR_CHARS.length)
            LOOKUP_ARRAY[OPERATOR_CHARS.charCodeAt(i)] = true;

        LOOKUP_ARRAY;
    };

    private var character:Int = 0;
    private var charCode:Int = -1;
    private var tokenMin:Int = 0;
    private var tokenMax:Int = 0;
    private var line:Int = 0;

    private var input:String = null;
    private var tokens:Array<LTokenPos> = [];

    public var origin:String = null;

    public function new(?origin:String) {
        this.origin = origin ?? "";
    }

    public function tokenize(string:String):Array<LTokenPos> {
        input = string ?? "";
        character = 0;

        while (true) {
			var ltoken:LToken = token();
			if (ltoken == LTEof) break;
            push(ltoken);
        }

        return tokens;
    }

    private function token() {
		tokenMin = (this.charCode < 0) ? this.character : this.character - 1;
		var ltoken = nativeToken();
		tokenMax = (this.charCode < 0) ? this.character - 1 : this.character - 2;
		return ltoken;
    }

    private function nativeToken() {
        var charCode:Int;
		if (this.charCode < 0)
			charCode = readCharacter();
		else {
			charCode = this.charCode;
			this.charCode = -1;
		}

        while (true) {
            if (StringTools.isEof(charCode)) {
                this.charCode = charCode;
                return LTEof;
            }

            switch (charCode) {
                case 0: return LTEof;
                case " ".code, "\t".code, 13: tokenMin++; // space, tab, cr
                case "\n".code: line++; tokenMin++; // line end
                case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0...9
                	var n:Int = charCode - 48;
				    var exp:Float = 0;
                    while (true) {
                        charCode = readCharacter();
                        exp *= 10;
                        switch (charCode) {
                            case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0...9
                                n = n * 10 + (charCode - 48);
                            case "e".code, "E".code:
                                var token:LToken = this.token();
                                var pow:Null<Int> = null;
                                switch(token) {
                                    case LTConst(LCInt(int)): pow = int;
                                    case LTOp(SUB): // negative numbers 
                                        token = this.token();
                                        switch(token) {
                                            case LTConst(LCInt(int)): pow = -int;
                                            default: push(token);
                                        }
                                    default: push(token);
                                }
                                if (pow == null) invalidChar(charCode);
                                if (exp == 0) exp = 10;

                                return LTConst(LCFloat((Math.pow(10, pow) / exp) * n * 10));
                            case ".".code:
                                if (exp > 0) { // in case of '0...'
                                    charCode = readCharacter();
                                    if (exp == 10 && charCode == ".".code) {
                                        push(LTOp(INTERVAL));
                                        var i:Int = Std.int(n);
                                        return LTConst((i == n) ? LCInt(i) : LCFloat(n));
                                    }
                                    invalidChar(charCode);
                                }
						        exp = 1;
                            case "x".code:
                                if (n > 0 || exp > 0)
                                    invalidChar(charCode);
                                
                                var hexa:Int = 0;
                                while (true) { // read hexa
                                    charCode = readCharacter();
                                    switch(charCode) {
                                        case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: hexa = (hexa << 4) + charCode - 48; // 0...9
                                        case 65, 66, 67, 68, 69, 70: hexa = (hexa << 4) + (charCode - 55); // A-F
                                        case 97, 98, 99, 100, 101, 102: hexa = (hexa << 4) + (charCode - 87); // a-f
                                        default: 
                                            this.charCode = charCode;
                                            return LTConst(LCInt(hexa));
                                    }
                                }
                            default:
                                this.charCode = charCode;

                                var i:Int = Std.int(n);
						        return LTConst((exp > 0) ? LCFloat(n * 10 / exp) : ((i == n) ? LCInt(i) : LCFloat(n)));
                        }
                    }
                case "(".code: return LTOpenP;
                case ")".code: return LTCloseP;
                case "[".code: return LTOpenBr;
                case "]".code: return LTCloseBr;
                case "{".code: return LTOpenCB;
                case "}".code: return LTCloseCB;
                case ",".code: return LTComma;
                case ".".code: 
                    charCode = readCharacter();
                    switch(charCode) {
                        case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0...9
                            var n:Int = charCode - 48;
                            var exp:Float = 1;
                            while (true) {
                                charCode = readCharacter();
                                exp *= 10;
                                switch(charCode) {
                                    case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0...9
                                        n = n * 10 + (charCode - 48);
                                    default:
                                        this.charCode = charCode;
                                        return LTConst(LCFloat(n / exp));
                                }
                            }
                        case ".".code:
                            charCode = readCharacter();
                            if (charCode != ".".code)
                                invalidChar(charCode);
                            return LTOp(INTERVAL);
                        default:
                            this.charCode = charCode;
                            return LTDot;
                    }
                    return LTDot;
                case ":".code: return LTColon;
                case ";".code: return LTSemiColon;
                case "?".code: return LTQuestion;
                case "'".code, '"'.code: return LTConst(LCString(readString(charCode)));
                case '='.code:
                    charCode = readCharacter();
                    if (charCode == '='.code) return LTOp(EQ);
                    else if (charCode == '>'.code) return LTOp(ARROW);
                    this.charCode = charCode;

				    return LTOp(ASSIGN);
                case '@'.code:
                    charCode = readCharacter();
                    if (IDENTIFIER_CHARS_LOOKUP[charCode] || charCode == ':'.code) {
                        var id = String.fromCharCode(charCode);
                        while (true) {
                            charCode = readCharacter();
                            if (!IDENTIFIER_CHARS_LOOKUP[charCode]) {
                                this.charCode = charCode;
                                return LTMeta(id);
                            }
                            id += String.fromCharCode(charCode);
                        }
                    }
                    invalidChar(charCode);
                case '#'.code:
                    charCode = readCharacter();
                    if (IDENTIFIER_CHARS_LOOKUP[charCode]) {
                        var id = String.fromCharCode(charCode);
                        while (true) {
                            charCode = readCharacter();
                            if (!IDENTIFIER_CHARS_LOOKUP[charCode]) {
                                this.charCode = charCode;
                                return LTPrepro(id);
                            }
                            id += String.fromCharCode(charCode);
                        }
                    }
                    invalidChar(charCode);
                default: 
                    if (OPERATOR_CHARS_LOOKUP[charCode]) {
                        var op:String = String.fromCharCode(charCode);
                        while (true) {
                            charCode = readCharacter();
                            if (StringTools.isEof(charCode)) charCode = 0;
                            if (!OPERATOR_CHARS_LOOKUP[charCode]) {
                                this.charCode = charCode;
                                return LTOp(op);
                            }
                            var preop:String = op;
                            op += String.fromCharCode(charCode);
                            
                            if (!LOp.OP_PRECEDENCE_LEFT_LOOKUP.exists(op) && LOp.OP_PRECEDENCE_LEFT_LOOKUP.exists(preop)) {
                                if (op == COMMENT || op == COMMENT_OPEN)
                                    return comment(op, charCode);

                                this.charCode = charCode;
                                return LTOp(preop);
                            }
                        }
                    }
                    if (IDENTIFIER_CHARS_LOOKUP[charCode]) {
                        var id = String.fromCharCode(charCode);
                        while (true) {
                            charCode = readCharacter();
                            if (StringTools.isEof(charCode)) charCode = 0;
                            if (!IDENTIFIER_CHARS_LOOKUP[charCode]) {
                                this.charCode = charCode;

                                if (LKeyword.ALL_KEYWORDS_LOOKUP.exists(id)) return LTKeyWord(id);
                                else return LTIdentifier(id);
                            }
                            id += String.fromCharCode(charCode);
                        }
                    }
                    invalidChar(charCode);
            }
            charCode = readCharacter();
        }

        return null;
    }

    inline function push(ltoken:LToken) {
		tokens.push({
            token : ltoken, 
            min : tokenMin, 
            max : tokenMax,
            line : line
        });
	}

    inline function readString(untilCharCode:Int) {
		var c:Int = 0;
		var b:StringBuf = new StringBuf();
		var esc:Bool = false;
		var oldLine:Int = line;

		var start:Int = character - 1;
		while (true) {
			var c:Int = readCharacter();
			if (StringTools.isEof(c)) {
				error(EUnterminatedString, start, start);
				line = oldLine;
				break;
			}

			if (esc) {
				esc = false;
				switch (c) {
                    case 'n'.code: b.addChar('\n'.code);
                    case 'r'.code: b.addChar('\r'.code);
                    case 't'.code: b.addChar('\t'.code);
                    case "'".code, '"'.code, '\\'.code: b.addChar(c);
                    case '/'.code: b.addChar(c);
                    case "u".code: // JSON parsing
                        var k:Int = 0;
                        for(i in 0...4) {
                            k <<= 4;
                            var char = readCharacter();
                            switch (char) {
                                case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: k += char - 48; // 0-9
                                case 65, 66, 67, 68, 69, 70: k += char - 55; // A-F
                                case 97, 98, 99, 100, 101, 102: k += char - 87; // a-f
                                default:
                                    if (StringTools.isEof(char)) {
                                        error(EUnterminatedString, start, start);
                                        line = oldLine;
                                    }
                                    invalidChar(char);
                                }
                        }
                        b.addChar(k);
				    default: invalidChar(c);
				}
			} else if (c == 92)
				esc = true;
			else if (c == untilCharCode)
				break;
			else {
				if (c == "\n".code) line++;
				b.addChar(c);
			}
		}
		return b.toString();
	}

    inline function comment(op:String, charCode:Int) {
		var secondCharCode:Int = op.charCodeAt(1);

		if (secondCharCode == '/'.code) { // comment
			while (charCode != '\r'.code && charCode != '\n'.code) {
				charCode = readCharacter();
				if (StringTools.isEof(charCode)) break;
			}
			this.charCode = charCode;
			return token();
		}

		if (secondCharCode == '*'.code) { /* comment */
			var oldLine:Int = line;
			if (op == "/**/") {
				this.charCode = charCode;
				return token();
			}

			while (true) {
				while (charCode != '*'.code) {
					if (charCode == '\n'.code) line++;
					charCode = readCharacter();
					if (StringTools.isEof(charCode)) {
						line = oldLine;
						error(EUnterminatedComment, tokenMin, tokenMin);
						break;
					}
				}

				charCode = readCharacter();
				if (StringTools.isEof(charCode)) {
					line = oldLine;
					error(EUnterminatedComment, tokenMin, tokenMin);
					break;
				}

				if (charCode == '/'.code) break;
			}
			return token();
		}
		this.charCode = charCode;
		return LTOp(op);
	}

    inline function invalidChar(c) {
        error(EInvalidChar(c), character-1, character-1);
    }

    inline function error(err:ErrorDef, pmin:Int, pmax:Int) {
		throw new Error(err, pmin, pmax, origin, line);
	}

    inline function readCharacter() {
		return StringTools.fastCodeAt(input, character++);
	}
}