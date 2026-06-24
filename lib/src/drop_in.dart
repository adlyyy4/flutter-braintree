import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';

import 'drop_in_sheet.dart';
import 'request.dart';
import 'result.dart';

class BraintreeDropIn {
  static const MethodChannel _kChannel = const MethodChannel('flutter_braintree.drop_in');

  const BraintreeDropIn._();

  /// Launches the Braintree Drop-in payment selection.
  ///
  /// On Android this presents the native Drop-in UI. On iOS, web, and other
  /// platforms it presents a Flutter payment sheet (the native iOS Drop-in SDK
  /// has no Braintree v7-compatible release), so a [BuildContext] is required.
  ///
  /// The required options can be placed inside the [request] object.
  /// See its documentation for more information.
  ///
  /// Returns a Future that resolves to a [BraintreeDropInResult] containing
  /// all the relevant information, or `null` if the selection was canceled.
  static Future<BraintreeDropInResult?> start(
    BuildContext context,
    BraintreeDropInRequest request,
  ) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final result = await _kChannel.invokeMethod(
        'start',
        request.toJson(),
      );
      if (result == null) return null;
      return BraintreeDropInResult.fromJson(result);
    }

    return showBraintreeDropInSheet(context, request);
  }
}
