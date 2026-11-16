// Runs conversions in a browser worker. Compiled by tool/build_worker.sh into web/convert_worker.js.

import 'dart:js_interop';

import 'package:radial_core/radial_core.dart';
import 'package:shiftdrop/worker_protocol.dart';
import 'package:web/web.dart' as web;

@JS('self')
external web.DedicatedWorkerGlobalScope get _self;

void main() {
  _self.onmessage = ((web.MessageEvent event) {
    _handle(event.data as WorkerRequest);
  }).toJS;
}

/// Every choice the page sent, as it sent them.
ActionOptions _options(WorkerRequest request) {
  final wire = request.options?.dartify();
  return wire is Map ? ActionOptions.fromWire(wire) : const ActionOptions();
}

Future<void> _handle(WorkerRequest request) async {
  void reply(WorkerReply message) => _self.postMessage(message);
  try {
    final files = [
      for (final file in request.files.toDart) PortableFile(file.name.toDart, file.bytes.toDart),
    ];
    final outputs = await runPortable(
      actionById(request.actionId.toDart)!,
      files,
      options: _options(request),
      onProgress: (progress) => reply(WorkerReply(progress: progress.toJS)),
    );
    reply(
      WorkerReply(
        files: [
          for (final file in outputs) WorkerFile(name: file.name.toJS, bytes: file.bytes.toJS),
        ].toJS,
      ),
    );
  } on PasswordNeeded catch (needed) {
    reply(WorkerReply(passwordNeeded: needed.fileName.toJS));
  } on EngineFailed catch (error) {
    reply(
      WorkerReply(
        failure: error.message.toJS,
        key: error.key?.toJS,
        args: error.args.jsify() as JSObject?,
      ),
    );
  } catch (_) {
    reply(
      WorkerReply(failure: Fail.somethingWrong.message.toJS, key: Fail.somethingWrong.key?.toJS),
    );
  }
}
