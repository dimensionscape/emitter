package emitter.signals;

/**
 * Represents the number of arguments expected by a signal listener.
 *
 * This is required when using `Emitter.once()` to correctly wrap the callback
 * with the appropriate arity. It ensures compatibility with all targets, especially
 * those that enforce strict function signatures at runtime (such as HashLink and Neko).
 *
 * Since Haxe does not provide reliable runtime function arity reflection, the arity
 * must be provided explicitly by the developer to ensure correct invocation.
 */
enum Arity {
	/** Listener expects no arguments. */
	Zero;

	/** Listener expects one argument. */
	One;

	/** Listener expects two arguments. */
	Two;

	/** Listener expects three arguments. */
	Three;

	/** Listener expects four arguments. */
	Four;

	/** Listener expects five arguments. */
	Five;

	/**
	 * Listener accepts a variable number of arguments (rest parameters).
	 *
	 * Use this if the callback uses dynamic or variadic parameters,
	 * such as when using `emitUntyped()` or `Reflect.makeVarArgs`.
	 */
	VarArgs;
}
