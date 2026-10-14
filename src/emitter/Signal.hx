package emitter;

/**
	A signal whose listeners are `F`: what `on`, `once`, `off`, `has`,
	`clear` and `emit` take. Declare a signal as one of `Signal0` to
	`Signal5`, which name only the arguments and become this where it is
	used.
**/
abstract Signal<F>(String) to String {}
