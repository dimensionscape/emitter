package support;

import haxe.macro.Context;
import haxe.macro.Expr;

/**
	Whether an expression compiles, asked of the compiler where the test
	is: for a line that must not.
**/
class TypeCheck {
	/**
		The compiler's error for `e`, typed where the call is, locals
		included; null when it compiles. Nothing of `e` runs.
	**/
	public static macro function errorOf(e:Expr):ExprOf<Null<String>> {
		try {
			Context.typeExpr(e);
		} catch (error:Dynamic) {
			return macro $v{Std.string(error)};
		}
		return macro null;
	}
}
