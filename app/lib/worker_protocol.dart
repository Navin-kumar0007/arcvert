import 'dart:js_interop';

/// A file crossing between the page and the conversion worker.
extension type WorkerFile._(JSObject _) implements JSObject {
  external factory WorkerFile({JSString name, JSUint8Array bytes});

  external JSString get name;
  external JSUint8Array get bytes;
}

/// What the page sends the worker: the action, the files, and every choice for it as plain
/// values (`ActionOptions.toWire`), so none can be left behind on the way.
extension type WorkerRequest._(JSObject _) implements JSObject {
  external factory WorkerRequest({JSString actionId, JSArray<WorkerFile> files, JSAny? options});

  external JSString get actionId;
  external JSArray<WorkerFile> get files;
  external JSAny? get options;
}

/// What the worker sends back: progress, then the results or why it failed.
extension type WorkerReply._(JSObject _) implements JSObject {
  external factory WorkerReply({
    JSNumber? progress,
    JSArray<WorkerFile>? files,
    JSString? failure,
    JSString? key,
    JSObject? args,
    JSString? passwordNeeded,
  });

  external JSNumber? get progress;
  external JSArray<WorkerFile>? get files;
  external JSString? get failure;

  /// Which message from `Fail` [failure] is, and what fills its blanks, so it can be translated.
  external JSString? get key;
  external JSObject? get args;

  /// The name of a locked file that no password given opens.
  external JSString? get passwordNeeded;
}
