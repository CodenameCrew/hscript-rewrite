package hscript;

import hscript.Lexer.LConst;
import hscript.Ast.ExprBinop;

class Interp {}

class StaticInterp {
    public static inline function evaluateBinop(op:ExprBinop, val1 :Dynamic, val2:Dynamic):Dynamic {
        switch (op) {
            case ADD: return val1 + val2;
            case SUB: return val1 - val2;
            case MULT: return val1 * val2;
            case DIV: return val1 / val2;
            case MOD: return val1 % val2;

            case AND: return val1 & val2;
            case OR: return val1 | val2;
            case XOR: return val1 ^ val2;
            case SHL: return val1 << val2;
            case SHR: return val1 >> val2;
            case USHR: return val1 >>> val2;

            case EQ: return val1 == val2;
            case NEQ: return val1 != val2;
            case GTE: return val1 >= val2;
            case LTE: return val1 <= val2;
            case GT: return val1 > val2;
            case LT: return val1 < val2;

            case BOR: return val1 || val2;
            case BAND: return val1 && val2;
            case IS: return Std.isOfType(val1 , val2);
            case NCOAL: return val1 ?? val2;

            case ADD_ASSIGN: return val1 += val2;
            case SUB_ASSIGN: return val1 -= val2;
            case MULT_ASSIGN: return val1 *= val2;
            case DIV_ASSIGN: return val1 /= val2;
            case MOD_ASSIGN: return val1 %= val2;
            case SHL_ASSIGN: return val1 <<= val2;
            case SHR_ASSIGN: return val1 >>= val2;
            case USHR_ASSIGN: return val1 >>>= val2;
            case OR_ASSIGN: return val1 |= val2;
            case AND_ASSIGN: return val1 &= val2;
            case XOR_ASSIGN: return val1 ^= val2;
            case NCOAL_ASSIGN: return val1 ??= val2;

            default: throw new Error(EInvalidOp("Invalid operator: " + op));
        }
    }

    public static inline function evaluateConst(const:LConst):Dynamic {
        return switch (const) {
            case LCInt(int): int;
            case LCFloat(float): float;
            case LCString(string): string;
        }
    }
}