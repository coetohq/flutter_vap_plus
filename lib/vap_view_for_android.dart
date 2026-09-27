import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'vap_controller.dart';
import 'vap_view.dart';

class VapViewForAndroid extends StatelessWidget {
  final void Function(VapController controller) onControllerCreated;
  final VapScaleFit fit;
  final void Function(dynamic event,dynamic arguments)? onEvent;
  final void Function(Object error)? onError;

  VapViewForAndroid(
      {required this.onControllerCreated,
      required this.fit,
      this.onEvent,
      this.onError});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'scaleType': fit.name
    };
    return AndroidView(
      viewType: "flutter_vap",
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: StandardMessageCodec(),
      onPlatformViewCreated: (viewId) {
        onControllerCreated(VapController(
          viewId: viewId,
          onEvent: onEvent
        ));
      },
    );
  }
}
