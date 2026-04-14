import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

@JS('braintree')
external _BraintreeNS get _braintree;

extension type _BraintreeNS._(JSObject _) implements JSObject {
  external _ClientModule get client;
  external _CardModule get card;
  external _PPCheckoutModule get paypalCheckout;
}

extension type _ClientModule._(JSObject _) implements JSObject {
  external JSPromise<_ClientInstance> create(JSObject options);
}

extension type _ClientInstance._(JSObject _) implements JSObject {}

extension type _CardModule._(JSObject _) implements JSObject {
  external JSPromise<_CardInstance> create(JSObject options);
}

extension type _CardInstance._(JSObject _) implements JSObject {
  external JSPromise<_CardPayload> tokenize(JSObject options);
}

extension type _CardPayload._(JSObject _) implements JSObject {
  external JSString get nonce;
  external JSString get type;
  external JSString get description;
}

extension type _PPCheckoutModule._(JSObject _) implements JSObject {
  external JSPromise<_PPCheckoutInstance> create(JSObject options);
}

extension type _PPCheckoutInstance._(JSObject _) implements JSObject {
  external JSString get clientId;
  external JSPromise<JSAny> createPayment(JSObject options);
  external JSPromise<_PPTokenizePayload> tokenizePayment(JSObject data);
}

extension type _PPTokenizePayload._(JSObject _) implements JSObject {
  external JSString get nonce;
  external JSString get type;
  external _PPDetails get details;
}

extension type _PPDetails._(JSObject _) implements JSObject {
  external JSString? get email;
  external JSString? get payerId;
}

@JS('paypal')
external _PayPalNS get _paypal;

extension type _PayPalNS._(JSObject _) implements JSObject {
  external _ButtonsComponent Buttons(JSObject options);
}

extension type _ButtonsComponent._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> render(JSString selector);
}

class BraintreeFlutterPlusWeb {
  static const _sdkVersion = '3.139.0';
  static const _cdnBase = 'https://js.braintreegateway.com/web/$_sdkVersion/js';

  static void _log(String msg) {
    // ignore: avoid_print
    print('[BraintreeFlutterPlusWeb] $msg');
  }

  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'flutter_braintree.custom',
      const StandardMethodCodec(),
      registrar,
    );
    final plugin = BraintreeFlutterPlusWeb();
    channel.setMethodCallHandler(plugin._handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    _log('→ ${call.method}');
    try {
      switch (call) {
        case MethodCall(
          method: 'tokenizeCreditCard',
          arguments: final Map arguments,
        ):
          return await _tokenizeCreditCard(arguments);
        case MethodCall(
          method: 'requestPaypalNonce',
          arguments: final Map arguments,
        ):
          return await _requestPaypalNonce(arguments);
        case MethodCall(:final method):
          throw PlatformException(
            code: 'unimplemented',
            message: '$method is not implemented on web',
          );
      }
    } catch (e, stack) {
      if (e is PlatformException) {
        _log('✗ ${call.method} — [${e.code}] ${e.message}');
        rethrow;
      }
      _log('✗ ${call.method} — unexpected: $e');
      _log('  stack: $stack');
      throw PlatformException(
        code: 'braintree_error',
        message: e.toString(),
        details: stack.toString(),
      );
    }
  }

  Future<void> _loadScript(String src) async {
    if (document.querySelector('script[src="$src"]') != null) {
      _log('script already present: $src');
      return;
    }

    _log('loading script: $src');
    final completer = Completer<void>();

    final script = HTMLScriptElement();
    script.src = src;
    script.defer = true;
    script.onload = ((Event _) {
      _log('script loaded: $src');
      completer.complete();
    }).toJS;
    script.onerror = ((Event _) {
      // script onerror does not expose the HTTP status code; open the URL in
      // DevTools → Network to confirm the exact failure (404, CORS, CSP, …).
      final err = PlatformException(
        code: 'braintree_script_load_error',
        message: 'Failed to load $src\n'
            'Common causes: wrong SDK version (check '
            'https://github.com/braintree/braintree-web/blob/main/CHANGELOG.md'
            ' for valid versions), CORS/CSP policy, or network error.\n'
            'Open browser DevTools → Network tab and filter by the filename '
            'to see the HTTP status.',
      );
      _log('✗ ${err.message}');
      completer.completeError(err);
    }).toJS;

    document.head!.appendChild(script);
    await completer.future;
  }

  Future<Map<String, dynamic>> _tokenizeCreditCard(Map args) async {
    final authorization = args['authorization'] as String;
    final request = args['request'] as Map;

    await _loadScript('$_cdnBase/client.min.js');
    await _loadScript('$_cdnBase/card.min.js');

    try {
      final clientInstance = await _braintree.client
          .create({'authorization': authorization}.jsify()! as JSObject)
          .toDart;

      final cardInstance = await _braintree.card
          .create({'client': clientInstance}.jsify()! as JSObject)
          .toDart;

      final tokenizeOptions = <String, Object?>{
        'number': request['cardNumber'],
        'expirationMonth': request['expirationMonth'],
        'expirationYear': request['expirationYear'],
      };
      if (request['cvv'] != null) tokenizeOptions['cvv'] = request['cvv'];
      if (request['cardholderName'] != null) {
        tokenizeOptions['cardholderName'] = request['cardholderName'];
      }

      final payload = await cardInstance
          .tokenize(tokenizeOptions.jsify()! as JSObject)
          .toDart;

      return {
        'nonce': payload.nonce.toDart,
        'typeLabel': payload.type.toDart,
        'description': payload.description.toDart,
        'isDefault': false,
        'paypalPayerId': null,
        'amount': request['amount'],
      };
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>?> _requestPaypalNonce(Map args) async {
    final authorization = args['authorization'] as String;
    final request = args['request'] as Map;
    final amount = request['amount'] as String?;
    final currencyCode = (request['currencyCode'] as String?) ?? 'USD';
    final intentRaw =
        (request['payPalPaymentIntent'] as String?) ?? 'authorize';
    final isVault = amount == null || amount.isEmpty;

    await _loadScript('$_cdnBase/client.min.js');
    await _loadScript('$_cdnBase/paypal-checkout.min.js');

    late _PPCheckoutInstance ppCheckoutInstance;

    try {
      final clientInstance = await _braintree.client
          .create({'authorization': authorization}.jsify()! as JSObject)
          .toDart;

      ppCheckoutInstance = await _braintree.paypalCheckout
          .create({'client': clientInstance}.jsify()! as JSObject)
          .toDart;
    } catch (e) {
      throw _mapError(e);
    }

    final clientId = ppCheckoutInstance.clientId.toDart;

    final sdkParams = StringBuffer('client-id=$clientId&components=buttons');
    if (isVault) {
      sdkParams.write('&vault=true');
    } else {
      sdkParams.write('&currency=$currencyCode');
      sdkParams.write('&intent=$intentRaw');
    }

    if (document.querySelector('script[data-bt-paypal-sdk]') == null) {
      final paypalScript =
          document.createElement('script') as HTMLScriptElement;
      paypalScript.src = 'https://www.paypal.com/sdk/js?$sdkParams';
      paypalScript.setAttribute('data-bt-paypal-sdk', 'true');
      final c = Completer<void>();
      paypalScript.onload = ((Event _) {
        _log('PayPal SDK loaded');
        c.complete();
      }).toJS;
      paypalScript.onerror = ((Event _) {
        final err = PlatformException(
          code: 'braintree_script_load_error',
          message: 'Failed to load PayPal SDK: ${paypalScript.src}\n'
              'Check browser DevTools → Network for HTTP status.',
        );
        _log('✗ ${err.message}');
        c.completeError(err);
      }).toJS;
      document.head!.appendChild(paypalScript);
      await c.future;
    }

    final overlay = _createOverlay();
    document.body!.appendChild(overlay);

    final completer = Completer<Map<String, dynamic>?>();

    final closeBtn = overlay.querySelector('#_bt_paypal_close');
    if (closeBtn == null) {
      throw PlatformException(
        code: 'braintree_internal_error',
        message: 'PayPal overlay close button not found — this is a bug',
      );
    }
    closeBtn.addEventListener(
      'click',
      ((Event _) {
        overlay.remove();
        if (!completer.isCompleted) completer.complete(null);
      }).toJS,
    );

    final createPaymentOptions = <String, Object?>{
      'flow': isVault ? 'vault' : 'checkout',
    };
    if (!isVault) {
      createPaymentOptions['amount'] = amount;
      createPaymentOptions['currency'] = currencyCode;
      createPaymentOptions['intent'] = intentRaw;
    }
    if (request['displayName'] != null) {
      createPaymentOptions['displayName'] = request['displayName'];
    }
    if (request['billingAgreementDescription'] != null) {
      createPaymentOptions['description'] =
          request['billingAgreementDescription'];
    }

    final onApprove = (JSObject data, JSObject actions) {
      ppCheckoutInstance
          .tokenizePayment(data)
          .toDart
          .then((payload) {
            overlay.remove();
            if (!completer.isCompleted) {
              final details = payload.details;
              completer.complete({
                'nonce': payload.nonce.toDart,
                'typeLabel': 'PayPal',
                'description': details.email?.toDart ?? '',
                'isDefault': false,
                'paypalPayerId': details.payerId?.toDart,
                'amount': amount,
              });
            }
          })
          .catchError((Object e) {
            overlay.remove();
            if (!completer.isCompleted) {
              completer.completeError(_mapError(e));
            }
          });
    }.toJS;

    final onCancel = () {
      overlay.remove();
      if (!completer.isCompleted) completer.complete(null);
    }.toJS;

    final onError = (JSObject err) {
      final codeJs = err.getProperty<JSString?>('code'.toJS);
      final code = codeJs?.toDart ?? '';
      overlay.remove();
      if (!completer.isCompleted) {
        if (code == 'PAYPAL_POPUP_CLOSED' ||
            code == 'PAYPAL_CANCELED_BY_BUYER') {
          completer.complete(null);
        } else {
          completer.completeError(_mapError(err));
        }
      }
    }.toJS;

    final buttonsOptions = <String, JSAny>{
      if (isVault)
        'createBillingAgreement': (() {
          return ppCheckoutInstance.createPayment(
            createPaymentOptions.jsify()! as JSObject,
          );
        }).toJS
      else
        'createOrder': (() {
          return ppCheckoutInstance.createPayment(
            createPaymentOptions.jsify()! as JSObject,
          );
        }).toJS,
      'onApprove': onApprove,
      'onCancel': onCancel,
      'onError': onError,
    };

    try {
      await _paypal.Buttons(
        buttonsOptions.jsify()! as JSObject,
      ).render('#_bt_paypal_button_container'.toJS).toDart;
    } catch (e) {
      overlay.remove();
      throw _mapError(e);
    }

    return completer.future;
  }

  HTMLDivElement _createOverlay() {
    final overlay = document.createElement('div') as HTMLDivElement;
    overlay.id = '_bt_paypal_overlay';
    overlay.setAttribute(
      'style',
      'position:fixed;top:0;left:0;width:100%;height:100%;'
          'background:rgba(0,0,0,0.5);z-index:2147483647;'
          'display:flex;align-items:center;justify-content:center;',
    );

    final card = document.createElement('div') as HTMLDivElement;
    card.setAttribute(
      'style',
      'background:#fff;border-radius:8px;padding:24px;'
          'min-width:320px;box-shadow:0 4px 20px rgba(0,0,0,0.3);',
    );

    final header = document.createElement('div') as HTMLDivElement;
    header.setAttribute(
      'style',
      'display:flex;justify-content:space-between;'
          'align-items:center;margin-bottom:16px;',
    );

    final title = document.createElement('span') as HTMLSpanElement;
    title.setAttribute(
      'style',
      'font-size:16px;font-weight:600;font-family:sans-serif;',
    );
    title.textContent = 'Pay with PayPal';

    final closeBtn = document.createElement('button') as HTMLButtonElement;
    closeBtn.id = '_bt_paypal_close';
    closeBtn.setAttribute(
      'style',
      'border:none;background:none;cursor:pointer;'
          'font-size:22px;line-height:1;color:#555;',
    );
    closeBtn.setAttribute('aria-label', 'Close');

    header.appendChild(title);
    header.appendChild(closeBtn);

    final btnContainer = document.createElement('div') as HTMLDivElement;
    btnContainer.id = '_bt_paypal_button_container';

    card.appendChild(header);
    card.appendChild(btnContainer);
    overlay.appendChild(card);

    return overlay;
  }

  PlatformException _mapError(Object e) {
    if (e is JSObject) {
      final msgJs = e.getProperty<JSString?>('message'.toJS);
      final codeJs = e.getProperty<JSString?>('code'.toJS);
      return PlatformException(
        code: codeJs?.toDart ?? 'braintree_error',
        message: msgJs?.toDart ?? 'Unknown error',
      );
    }
    return PlatformException(code: 'braintree_error', message: e.toString());
  }
}
