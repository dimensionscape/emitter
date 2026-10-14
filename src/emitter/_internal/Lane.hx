package emitter._internal;

import emitter.IEmitter;
import haxe.Constraints.Function;
import haxe.ds.StringMap;

/**
	One lane of an emitter: the listeners of each name, for events or for
	signals. Made when the lane gets its first listener, so an emitter
	nothing listens to holds none.

	**Finding a name.** Natively, on the jvm and on JavaScript, the names
	listened for while there have been no more than `CHAINED` at once are
	chained in `Slot`s, in the order each was first added; past that they
	are in `map`. Walking a few links finds a name sooner than a map's
	lookup does (natively by which string it is before what it says), takes
	less memory than a map, and leaves a dispatch small enough for a JIT to
	inline whole. On eval, HashLink and Neko the names are always in a map.
	Never both: once there is a map, every name is in it.

	Where names are chained, the lane is the first slot itself, so finding
	the first name reads no more than finding a field; elsewhere the lane is
	the map itself, for the same reason.

	**A name nothing listens for** is told natively and on the jvm by
	`mask`, one bit for each name chained, chosen by the name's hash, which
	a string there keeps (natively a literal's is made when it is
	compiled): a name whose bit is clear is not there, and is not compared
	with each one that is. On the jvm each slot keeps its name's hash, so
	the mask is made again from ints. Natively it is made only when a name nothing
	listens for is looked for among two or more, so adding and removing
	names pays nothing for it; on the jvm, where the first name's hash is
	read by every lookup, as names come and go. JavaScript compares two
	names by `==`, which for the strings a program names is as cheap, and
	keeps no mask.

	**Changing a list during a dispatch.** A dispatch walks the array that
	was current when it reached this emitter, without copying it, and stops
	at the length it had then. While one is walking (`walking` above 0),
	removing a listener or putting one anywhere but last replaces the array
	instead of changing it, so the walk goes on over what it started with:
	a listener removed during a dispatch still runs for it, and one added
	does not. One added last is appended where it is, beyond where the walk
	stops. Otherwise an array is changed where it is, so a list of n
	listeners costs n, not n squared, to build and to empty.

	A list is never empty: the name goes when its last listener does. Every
	listener taken out of a list is marked `Listener.GONE`.

	**In a jvm build's macros**, which run on eval with `jvm` defined and the
	java package out of reach, every name hashes alike and is told by `==`.
**/
@:noCompletion
final class Lane extends #if (cpp || js || jvm) Slot #else StringMap<Array<Listener>> #end {
	/**
		What `add` and `remove` did: added or removed one, others remaining.
		`add` answers 0 or more when it added nothing: where the listener
		already there is.
	**/
	public static inline var CHANGED:Int = -1;

	/** What `add` did: the name's first listener; what `remove` did: its last. **/
	public static inline var TRANSITION:Int = -2;

	/** What `remove` did: nothing, the listener not being there. **/
	public static inline var NOT_FOUND:Int = -3;

	#if (cpp || js || jvm)
	/**
		How many names are chained before they all go into a map: as many as
		a walk was measured to find no later than the map would, a name
		nothing listens for included. Natively 8, where a walk compares
		which string each name is before its text, and on JavaScript 4,
		where it compares text (CrossByte's measurements); the jvm compares
		text as JavaScript does, and takes its 4.
	**/
	public static inline var CHAINED:Int = #if cpp 8 #else 4 #end;

	/** Every name and its listeners, by name, once they are not chained. **/
	public var map:Null<StringMap<Array<Listener>>>;

	#end

	#if (jvm || (cpp && !cppia))
	/**
		One bit for each name chained, `1 << (hash & 31)`; natively
		`UNKNOWN` until a miss needs it after names came or went.
	**/
	public var mask:Int;
	#end

	#if (cpp && !cppia)
	/** `mask` not made since names came or went: no chain of 8 names sets every bit. **/
	static inline var UNKNOWN:Int = -1;
	#end

	/** How many dispatches are walking one of this lane's lists now. **/
	public var walking:Int;

	/** Whether a listener added again for a name is kept again. **/
	public var keepDuplicates:Bool;

	/** On the event lane, the emitter events are dispatched for, if not the owner. **/
	public var target:Null<IEmitter>;

	public function new(target:Null<IEmitter>) {
		#if (cpp || js || jvm)
		super(null, null);
		map = null;
		#if jvm
		mask = 0;
		#elseif (cpp && !cppia)
		mask = UNKNOWN;
		#end
		#else
		super();
		#end
		walking = 0;
		keepDuplicates = false;
		this.target = target;
	}

	/**
		The listeners for `type` in the order they run, or null for none. The
		array is the one a dispatch walks: read it, never change it.
	**/
	public inline function listOf(type:String):Null<Array<Listener>> {
		#if (cpp || js)
		// The first chained name is found by one compare: with none chained,
		// `this.type` is null and `this.list` too, so even a null name
		// matching it finds nothing.
		return sameString(this.type, type) ? this.list : listAfter(type);
		#elseif jvm
		var hash:Int = hashOf(type);
		return (this.hash == hash && sameText(this.type, type)) ? this.list : listAfter(type, hash);
		#else
		return mapped(type);
		#end
	}

	private inline function mapped(type:String):Null<Array<Listener>> {
		#if (cpp || js || jvm)
		var map = this.map;
		return (map == null || type == null) ? null : map.get(type);
		#else
		return type == null ? null : get(type);
		#end
	}

	/**
		Adds `entry` for `type`, after the others of its priority. With
		`dedupe`, a function already there for `type` is not added again, and
		keeps its place.

		Inlined where an emitter adds, so the usual add (a listener after the
		last) costs one call fewer; anything else is `insert`'s.

		@return `CHANGED`, `TRANSITION` for the name's first, or, when the
		function was there already, where it is in `listOf(type)`.
		@throws haxe.exceptions.ArgumentException When `type` is null: a null
		name is never found, so it always comes here.
	**/
	public inline function add(type:String, entry:Listener, dedupe:Bool):Int {
		var list:Null<Array<Listener>> = listOf(type);
		var result:Int = TRANSITION;
		if (list == null) {
			if (type == null) {
				refuseNullType();
			}
			addType(type, [entry]);
		} else {
			var at:Int = dedupe ? indexOf(list, entry.fn) : -1;
			if (at >= 0) {
				result = at;
			} else {
				if (list[list.length - 1].priority >= entry.priority) {
					list.push(entry);
				} else {
					insert(type, list, entry);
				}
				result = CHANGED;
			}
		}
		return result;
	}

	private static function refuseNullType():Void {
		throw new haxe.exceptions.ArgumentException("type", "A name must not be null");
	}

	/**
		Puts `entry` before the first listener for `type` of a lower
		priority. While a dispatch walks the list, into a copy that replaces
		it.
	**/
	private function insert(type:String, list:Array<Listener>, entry:Listener):Void {
		var priority:Int = entry.priority;
		var length:Int = list.length;
		var at:Int = 0;
		while (at < length && list[at].priority >= priority) {
			at++;
		}
		if (walking > 0) {
			var next:Array<Listener> = list.copy();
			next.insert(at, entry);
			replace(type, next);
		} else {
			list.insert(at, entry);
		}
	}

	/**
		Removes the first listener for `type` that is `fn`. Inlined where an
		emitter removes, as `add` is.

		@return `NOT_FOUND`, `CHANGED`, or `TRANSITION` for the name's last.
	**/
	public inline function removeListener(type:String, fn:Function):Int {
		var list:Null<Array<Listener>> = listOf(type);
		var at:Int = list == null ? -1 : indexOf(list, fn);
		return at < 0 ? NOT_FOUND : removeAt(type, list, at);
	}

	/** Where `fn` is in `list`, or -1. **/
	public static inline function indexOf(list:Array<Listener>, fn:Function):Int {
		var found:Int = -1;
		var i:Int = 0;
		var length:Int = list.length;
		while (i < length) {
			if (same(list[i].fn, fn)) {
				found = i;
				break;
			}
			i++;
		}
		return found;
	}

	/**
		Removes `entry` itself, found by identity rather than by its
		function: a subscription cancelled, or a `once` listener called.
	**/
	public function removeEntry(type:String, entry:Listener):Int {
		var list:Null<Array<Listener>> = listOf(type);
		if (list != null) {
			for (i in 0...list.length) {
				if (list[i] == entry) {
					return removeAt(type, list, i);
				}
			}
		}
		return NOT_FOUND;
	}

	/**
		Removes `list[at]` where it is, from the list a walk is going over:
		for the only walk of this lane, over its own list, which does not
		move on past `at`. The last listener leaves the array as it is: the
		name goes, and the walk ends.
	**/
	public function removeWalked(type:String, list:Array<Listener>, at:Int):Int {
		list[at].state |= Listener.GONE;
		var length:Int = list.length;
		if (length == 1) {
			forget(type);
			return TRANSITION;
		}
		var i:Int = at + 1;
		while (i < length) {
			list[i - 1] = list[i];
			i++;
		}
		list.pop();
		return CHANGED;
	}

	/** Whether `fn` listens for `type`. **/
	public function has(type:String, fn:Function):Bool {
		var list:Null<Array<Listener>> = listOf(type);
		return list != null && indexOf(list, fn) >= 0;
	}

	/**
		Forgets `type` and its listeners: the list it had, in the order it
		ran, or null when it had none.
	**/
	public function removeType(type:String):Null<Array<Listener>> {
		var list:Null<Array<Listener>> = listOf(type);
		if (list == null) {
			return null;
		}
		markGone(list);
		forget(type);
		return list;
	}

	/**
		Forgets every name: the lists it had, one for each name, in no
		particular order (each listener keeps its name), or null when it had
		none. Dispatches walking a list go on over it.
	**/
	public function clearAll():Null<Array<Array<Listener>>> {
		var lists:Null<Array<Array<Listener>>> = null;
		#if !(cpp || js || jvm)
		for (type in keys()) {
			if (lists == null) {
				lists = [];
			}
			var list:Array<Listener> = get(type);
			lists.push(list);
			markGone(list);
		}
		clear();
		#else
		var slot:Null<Slot> = head();
		while (slot != null) {
			if (lists == null) {
				lists = [];
			}
			lists.push(slot.list);
			markGone(slot.list);
			slot = slot.next;
		}
		dropChain();
		var map = this.map;
		if (map != null) {
			for (list in map) {
				if (lists == null) {
					lists = [];
				}
				lists.push(list);
				markGone(list);
			}
		}
		this.map = null;
		#end
		return lists;
	}

	private static function markGone(list:Array<Listener>):Void {
		for (i in 0...list.length) {
			list[i].state |= Listener.GONE;
		}
	}

	/** Whether `a` and `b` are one listener: see `Emitter.off`. **/
	public static inline function same(a:Function, b:Function):Bool {
		#if (cpp || js)
		// hxcpp compares two reads of one bound method equal, and JavaScript
		// caches the binding: `==` is enough.
		return a == b;
		#else
		// On eval, neko and the jvm each read of `this.method` is a new
		// closure `==` never matches.
		return a == b || Reflect.compareMethods(a, b);
		#end
	}

	/**
		Removes `list[at]`, `list` being the listeners for `type` now: where
		it is, or while a dispatch walks the list, from a copy that replaces
		it. @return `CHANGED`, or `TRANSITION` for the name's last.
	**/
	public inline function removeAt(type:String, list:Array<Listener>, at:Int):Int {
		var result:Int = CHANGED;
		list[at].state |= Listener.GONE;
		var length:Int = list.length;
		if (length == 1) {
			forget(type);
			result = TRANSITION;
		} else if (walking > 0) {
			var next:Array<Listener> = list.copy();
			next.splice(at, 1);
			replace(type, next);
		} else {
			// Moved down by hand: `splice` makes an array of what it removes,
			// which would be garbage on every removal on the jvm and JavaScript.
			var i:Int = at + 1;
			while (i < length) {
				list[i - 1] = list[i];
				i++;
			}
			list.pop();
		}
		return result;
	}

	/** Forgets `type` and its list, which has listeners. **/
	private function forget(type:String):Void {
		#if !(cpp || js || jvm)
		remove(type);
		#else
		var map = this.map;
		if (map != null) {
			map.remove(type);
			return;
		}
		#if (cpp && !cppia)
		// It was most likely found by which string it is: that first.
		if (!unlink(type, true)) {
			unlink(type, false);
		}
		#else
		unlink(type, false);
		#end
		#if jvm
		mask = maskOfChain();
		#elseif (cpp && !cppia)
		mask = UNKNOWN;
		#end
		#end
	}

	/** Puts `list` in place of the listeners of `type`, which has some. **/
	private function replace(type:String, list:Array<Listener>):Void {
		#if !(cpp || js || jvm)
		set(type, list);
		#else
		var map = this.map;
		if (map != null) {
			map.set(type, list);
			return;
		}
		var slot:Null<Slot> = head();
		while (slot != null) {
			if (sameString(slot.type, type) #if (cpp && !cppia) || slot.type == type #end) {
				slot.list = list;
				return;
			}
			slot = slot.next;
		}
		#end
	}

	/** A name's first listeners: chained, or mapped once there are many. **/
	private function addType(type:String, list:Array<Listener>):Void {
		#if !(cpp || js || jvm)
		set(type, list);
		#else
		var map = this.map;
		if (map != null) {
			map.set(type, list);
			return;
		}
		var first:Null<Slot> = head();
		if (first == null) {
			this.type = type;
			this.list = list;
			#if jvm
			this.hash = hashOf(type);
			mask = 1 << (this.hash & 31);
			#elseif (cpp && !cppia)
			mask = UNKNOWN;
			#end
			return;
		}
		var count:Int = 1;
		var last:Slot = first;
		while (last.next != null) {
			last = last.next;
			count++;
		}
		if (count < CHAINED) {
			var slot:Slot = new Slot(type, list);
			last.next = slot;
			#if jvm
			mask |= 1 << (slot.hash & 31);
			#elseif (cpp && !cppia)
			mask = UNKNOWN;
			#end
			return;
		}
		// One more than the chain keeps: all of them go into a map, and stay
		// there. A lane that went past the chain once may again.
		map = new StringMap();
		var slot:Null<Slot> = first;
		while (slot != null) {
			map.set(slot.type, slot.list);
			slot = slot.next;
		}
		dropChain();
		map.set(type, list);
		this.map = map;
		#end
	}

	#if (cpp || js || jvm)
	/** The first chained slot, or null: the lane itself, while it holds a name. **/
	private inline function head():Null<Slot> {
		return this.type == null ? null : this;
	}

	/** Forgets the whole chain. **/
	private inline function dropChain():Void {
		this.type = null;
		this.list = null;
		this.next = null;
		#if jvm
		this.hash = 0;
		mask = 0;
		#elseif (cpp && !cppia)
		mask = UNKNOWN;
		#end
	}

	#if (jvm || (cpp && !cppia))
	/**
		The mask of the names chained now: on the jvm from the hashes their
		slots keep, natively from the ones their strings keep.
	**/
	private function maskOfChain():Int {
		var bits:Int = 0;
		var slot:Null<Slot> = head();
		while (slot != null) {
			bits |= 1 << ((#if jvm slot.hash #else hashOf(slot.type) #end) & 31);
			slot = slot.next;
		}
		return bits;
	}
	#end

	/** Takes the chained `type` out: found by which string it is, or by its text. **/
	private function unlink(type:String, byPointer:Bool):Bool {
		var first:Null<Slot> = head();
		if (first == null) {
			return false;
		}
		if (matches(first.type, type, byPointer)) {
			// The lane is the first slot: the second moves into it.
			var second:Null<Slot> = next;
			if (second == null) {
				this.type = null;
				this.list = null;
				#if jvm
				this.hash = 0;
				#end
			} else {
				this.type = second.type;
				this.list = second.list;
				this.next = second.next;
				#if jvm
				this.hash = second.hash;
				#end
			}
			return true;
		}
		var previous:Slot = first;
		var slot:Null<Slot> = first.next;
		while (slot != null) {
			if (matches(slot.type, type, byPointer)) {
				previous.next = slot.next;
				return true;
			}
			previous = slot;
			slot = slot.next;
		}
		return false;
	}

	private static inline function matches(a:Null<String>, b:String, byPointer:Bool):Bool {
		#if (cpp && !cppia)
		return byPointer ? sameString(a, b) : a == b;
		#else
		return sameString(a, b);
		#end
	}

	/**
		The listeners for `type`, known not to be the first chained one, or
		null; with nothing chained, from the map. An emitter is mostly asked
		about the very strings it was given, so natively the walk compares
		which string each is first, which costs nothing, and only then, if
		`mask` says it may be there, their text (with one name chained, at
		once, which is cheaper than a hash). On
		JavaScript one walk by `==` is as cheap; on the jvm `mask` is read
		first, and the walk compares hashes before text.
	**/
	public function listAfter(type:String #if jvm , hash:Int #end):Null<Array<Listener>> {
		if (this.type == null) {
			return mapped(type);
		}
		#if jvm
		if ((mask >>> (hash & 31)) & 1 == 0) {
			return null;
		}
		#end
		var first:Slot = this;
		var slot:Null<Slot> = next;
		while (slot != null) {
			#if jvm
			if (slot.hash == hash && sameText(slot.type, type)) {
				return slot.list;
			}
			#else
			if (sameString(slot.type, type)) {
				return slot.list;
			}
			#end
			slot = slot.next;
		}
		#if (cpp && !cppia)
		if (type == null) {
			return null;
		}
		var length:Int = type.length;
		if (next == null) {
			var only:String = first.type;
			return (only.length == length && only == type) ? first.list : null;
		}
		var bits:Int = mask;
		if (bits == UNKNOWN) {
			bits = maskOfChain();
			mask = bits;
		}
		if ((bits >>> (hashOf(type) & 31)) & 1 == 0) {
			return null;
		}
		slot = first;
		while (slot != null) {
			var other:String = slot.type;
			if (other.length == length && other == type) {
				return slot.list;
			}
			slot = slot.next;
		}
		#end
		return null;
	}

	/**
		Whether two names are the one string: natively by where their text
		is, which costs nothing where hxcpp's `==` is a call; on JavaScript
		by `==`, as cheap there; on the jvm by hash, then text.
	**/
	public static inline function sameString(a:Null<String>, b:Null<String>):Bool {
		#if (cpp && !cppia)
		return untyped __cpp__("({0}.raw_ptr() == {1}.raw_ptr())", a, b);
		#elseif jvm
		return if (a == null || b == null) {
			a == null && b == null;
		} else {
			hashOf(a) == hashOf(b) && sameText(a, b);
		}
		#else
		return a == b;
		#end
	}
	#end

	#if (jvm || (cpp && !cppia))
	/**
		The hash a string keeps, null's being 0. On the jvm `==` between two
		strings is `compareTo`, which reads every character even of the very
		same string: a hash, and then `equals`, which looks at identity
		first, tell two names apart at once. Natively a literal's hash was
		made when it was compiled, and another string's is kept once made.
	**/
	public static inline function hashOf(type:Null<String>):Int {
		#if (jvm && macro)
		// A jvm build's macros run with `jvm` defined and the java package out
		// of reach: one hash for every name, which leaves the text to decide.
		return 0;
		#elseif jvm
		return type == null ? 0 : (cast type : java.NativeString).hashCode();
		#else
		return untyped __cpp__("((int)({0}.hash()))", type);
		#end
	}
	#end

	#if jvm

	/** `equals`, for two names whose hashes agree. **/
	public static inline function sameText(a:Null<String>, b:Null<String>):Bool {
		#if macro
		return a != null && a == b;
		#else
		return a != null && (cast a : java.NativeString).equals(b);
		#end
	}
	#end
}

#if (cpp || js || jvm)
/**
	A chained name and its listeners: a lookup finds both in one object, so
	nothing can pair one name with another's listeners. The lane is its own
	first slot, and takes the second's name when the first goes.
**/
@:noCompletion
class Slot {
	public var type:Null<String>;

	/** Its listeners, in the order they run; never empty while chained. **/
	public var list:Null<Array<Listener>>;

	public var next:Null<Slot>;

	#if jvm
	/** The hash of `type`, kept so a walk compares two ints before any text. **/
	public var hash:Int;
	#end

	public function new(type:Null<String>, list:Null<Array<Listener>>) {
		this.type = type;
		this.list = list;
		this.next = null;
		#if jvm
		this.hash = Lane.hashOf(type);
		#end
	}
}
#end
