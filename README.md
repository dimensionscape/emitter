# Emitter Haxe Library

Emitter provides a simple yet powerful and extendable event-like signal emitter system for Haxe 4.2+ projects. It allows you to create and manage signals, subscribe to them, emit event-based signals, and handle callbacks with type safety. This library is especially useful for implementing event-driven architectures and managing communication between different parts of your application while ensuring maximum performance and efficient decoupling.

## Features

- **Type Safety**: Callback functions are typed, ensuring that the arguments passed match the expected types.
- **Multiple Signals**: Supports multiple signals from a single emitter, each with its own set of subscribed callbacks without creating an object for every signal as you might see in alternative libraries.
- **Arbitrary Callback Parameters**: Supports multiple callback argument type parameters without relying on object creation seen in a typical "EventDispatcher" while also perserving type safety checks in order to avoid errors.
- **Subscription Management**: Easily subscribe to, unsubscribe from and control emitters.
- **Flexible Event Handling**: Supports emitting signals with varying numbers of arguments, including both typed and untyped variations.
- **Simple API**: Designed to be straightforward and easy to use.
- **High Performance**: Built for real world use cases with performance in mind. Emitter outperforms most if not all other available alternative haxelibs designed for event handling.
- **Extendability and Reusability**: Designed for maximum extendability and reusability.
- **Chaining**: Method calls can be chained together for concise and readable code.
- **GC Friendly**: Avoids excessive object creation leading to a smaller resource footprint and less garbage collection. 

## Installation

You can install the Emitter Signals Library via Haxelib:

```bash
haxelib install emitter
```

## Usage

Here's a basic example of how to use the library:

### Imports
```hx
import emitter.Emitter;
import emitter.signals.SignalType;
```

### Create the Signal
```hx
public static inline var TEST:SignalType1<Int->Void, Int> = "test";
```

### Instantiate a new Emitter and assign a callback to your signal
```hx
// Create an instance of Emitter
var emitter:Emitter = new Emitter();

// Define a callback function for a signal
var callback:Int->Void = function(n:Int) {
    trace("Received data: " + n);
};

// Subscribe to a signal
emitter.on(TEST, callback);

// Emit the signal with an argument
emitter.emit(TEST, 42);

// Unsubscribe the callback from the signal
emitter.off(TEST, callback);
```

For more advanced usage and detailed information, please refer to the code documentation or check out the examples in the example/ directory.

## Requirements

- **Haxe 4.2+**

*(Note: This library uses the latest haxe features like method overloading and rest arguments)*

## Running Tests

To execute the test suite locally, run the following command:

```bash
haxe test/test.hxml
```

This will compile and run the tests using the `utest` framework.

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please feel free to open an issue or submit a pull request on GitHub.

## License

This library is released under the MIT License, which allows for free use, modification, and distribution, provided that proper credit is given to the original author(s). See the LICENSE file for more information.

*Happy coding!*
