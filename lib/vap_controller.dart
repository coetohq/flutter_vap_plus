import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

class VapController {
  late final MethodChannel _methodChannel;
  final int viewId;
  final void Function(dynamic event, dynamic arguments)? onEvent;

  VapController({
    required this.viewId,
    this.onEvent,
  }) {
    _methodChannel = MethodChannel('flutter_vap_controller_$viewId');
    _methodChannel.setMethodCallHandler(_onMethodCallHandler);
  }

  Completer<void>? playCompleter;


  Future<void> play(
      {required String source, required String playMethod, required String playArg, List<
          FetchResourceModel> fetchResources = const []}) async {
    final completer = Completer<void>();
    playCompleter = completer;
    /// 先设置融合动画参数再播放，不然会出现融合动画不起作用的问题
    await setFetchResources(fetchResources);

    await _methodChannel.invokeMethod(playMethod, {playArg: source});

    return completer.future.timeout(const Duration(seconds: 20));
  }

  Future<void> playPath(String path,
      {List<FetchResourceModel> fetchResources = const []}) {
    return play(source: path,
        playMethod: 'playPath',
        playArg: 'path',
        fetchResources: fetchResources);
  }

  Future<void> playAsset(String asset,
      {List<FetchResourceModel> fetchResources = const []}) {
    return play(source: asset,
        playMethod: 'playAsset',
        playArg: 'asset',
        fetchResources: fetchResources);
  }

  Future<void> stop() async {
    await _methodChannel.invokeMethod('stop');
    _completePlay(error: StateError('playback stopped'));
  }

  Future setFetchResources(List<FetchResourceModel> resources) {
    return _methodChannel.invokeMethod(
        'setFetchResource',
        jsonEncode(resources.map((e) => e.toMap()).toList()));
  }

  void dispose() {
    _methodChannel.setMethodCallHandler(null);
  }

  Future _onMethodCallHandler(MethodCall call) async {
    onEvent?.call(call.method, call.arguments);
    switch (call.method) {
      case "onComplete":
        _completePlay();
        break;
      case "onFailed":
        _completePlay(error: call.arguments);
        break;
    }
  }

  void _completePlay({Object? error}) {
    final completer = playCompleter;
    if (completer == null || completer.isCompleted) return;
    if (error == null) {
      completer.complete();
    } else {
      completer.completeError(error);
    }
  }
}

class FetchResourceModel {
  /// vap资源文件中预设的tag
  /// Preset tag in vap resource file
  final String tag;

  /// 图片本地路径或者文本字符串
  /// image local path or text
  final String resource;

  FetchResourceModel({required this.tag, required this.resource});

  Map<String, String> toMap() =>
      {
        'tag': tag,
        'resource': resource,
      };

}
