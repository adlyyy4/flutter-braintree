# Braintree Flutter Plus

[![pub package](https://img.shields.io/pub/v/braintree_flutter_plus.svg)](https://pub.dev/packages/braintree_flutter_plus)
[![GitHub](https://img.shields.io/github/license/adlyyy4/flutter-braintree)](https://github.com/adlyyy4/flutter-braintree/blob/main/LICENSE)

An enhanced Flutter plugin that wraps the native [Braintree SDKs](https://www.braintreepayments.com/features/seamless-checkout/drop-in-ui) with the latest updates and improvements.
Unlike other plugins, this plugin not only lets you start Braintree's native Drop-in UI, but also allows you to create your own custom Flutter UI with Braintree functionality.

## 🔄 About This Fork

This is an **actively maintained fork** of the original `flutter_braintree` package by [pikaju](https://github.com/pikaju/flutter-braintree), which is no longer being maintained. We've taken over development to provide:

- 🛠️ **Critical bug fixes** and security updates
- 📱 **Modern platform support** (iOS 16+, Android 12+)
- 🔄 **Regular maintenance** and dependency updates
- 📦 **Published as `braintree_flutter_plus`** on pub.dev

> **Migration Note**: If you're using the original `flutter_braintree`, simply replace it with `braintree_flutter_plus` in your `pubspec.yaml` - the API remains the same!

## ✨ What's New in Plus

- **iOS Braintree SDK v7**: Fixes the Xcode 26 `-Wdeprecated-declarations` build failure; requires iOS 16+
- **Cross-platform Drop-in on iOS/web**: the native iOS Drop-in SDK (no v7 release) is replaced by a Flutter payment sheet; Android keeps the native Drop-in
- **Android 12+ Compatibility**: Fixed crashes and added proper exported flags
- **PayPal Vault Flow**: Resolved critical Android crashes
- **Enhanced Stability**: Updated Cardinal SDK and core dependencies

## Installation

Add braintree_flutter_plus to your `pubspec.yaml` file:

```yaml
dependencies:
  ...
  braintree_flutter_plus: ^5.0.0
```

### Android

You must [migrate to AndroidX.](https://flutter.dev/docs/development/packages-and-plugins/androidx-compatibility)  
In `/app/build.gradle`, set your `minSdkVersion` to at least `21`.

#### Card.io

[Card.io](https://github.com/card-io) enables credit card scanning so as to remove the need to type in credit card details manually.
This feature became optional in `flutter_braintree` version `0.6.0` to potentially reduce app sizes.
To enable it for the Braintree Drop-in UI, add the following line to your `app` level `build.gradle` file:

```gradle
dependencies {
    ...
    implementation 'io.card:android-sdk:5.+'
}
```

#### PayPal / Venmo / 3D Secure

In order for this plugin to support PayPal, Venmo or 3D Secure payments, you must allow for the
browser switch by adding an intent filter to your `AndroidManifest.xml` (inside the `<application>` body):

```xml
<activity android:name="com.braintreepayments.api.DropInActivity"
    android:launchMode="singleTask">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="${applicationId}.braintree" />
    </intent-filter>
</activity>
<activity android:name="com.braintreepayments.api.ThreeDSecureActivity" android:theme="@style/Theme.AppCompat.Light" android:exported="true">
</activity>

<!-- Required for built-in credit card form -->
<activity
    android:name="com.example.flutter_braintree.FlutterBraintreeCustom"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar"
    android:exported="true"/>
```

**Important:** Your app's URL scheme must begin with your app's package ID and end with `.braintree`. For example, if the Package ID is `com.your-company.your-app`, then your URL scheme should be `com.your-company.your-app.braintree`. `${applicationId}` is automatically applied with your app's package when using Gradle.
**Note:** The scheme you define must use all lowercase letters. If your package contains underscores, the underscores should be removed when specifying the scheme in your Android Manifest.

#### Google Pay

Add the wallet enabled meta-data tag to your `AndroidManifest.xml` (inside the `<application>` body):

```xml
<meta-data android:name="com.google.android.gms.wallet.api.enabled" android:value="true"/>
```

### iOS

You may need to add or uncomment the following line at the top of your `ios/Podfile`:

```ruby
platform :ios, '16.0'
```

Braintree v7 requires a minimum deployment target of **iOS 16.0**.

#### PayPal / Venmo / 3D Secure

In your App Delegate or your Runner project, you need to specify the URL scheme for redirecting payments as following:

```swift
BTAppContextSwitcher.setReturnURLScheme("com.your-company.your-app.payments")
```

Moreover, you need to specify the same URL scheme in your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.your-company.your-app.payments</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.your-company.your-app.payments</string>
        </array>
    </dict>
</array>
```

See the official [Braintree documentation](https://developers.braintreepayments.com/guides/paypal/client-side/ios/v4) for a more detailed explanation.

## Usage

You must first create a [Braintree account](https://www.braintreepayments.com/). In your control panel you can create a tokenization key. You likely also want to set up a backend server. Make sure to read the [Braintree developer documentation](https://developers.braintreepayments.com/) so you understand all key concepts.

In your code, import the plugin:

```dart
import 'package:flutter_braintree/flutter_braintree.dart';
```

You can then create your own user interface using Flutter or use Braintree's drop-in UI.

### Flutter UI

#### Credit cards

Create a credit card request object:

```dart
final request = BraintreeCreditCardRequest(
  cardNumber: '4111111111111111',
  expirationMonth: '12',
  expirationYear: '2021',
  cvv: '367'
);
```

Then ask Braintree to tokenize it:

```dart
BraintreePaymentMethodNonce result = await Braintree.tokenizeCreditCard(
   '<Insert your tokenization key or client token here>',
   request,
);
print(result.nonce);
```

#### PayPal

Create a PayPal request object:

```dart
final request = BraintreePayPalRequest(amount: '13.37');
```

Or, for the Vault flow:

```dart
final request = BraintreePayPalRequest(
  billingAgreementDescription: 'I hereby agree that flutter_braintree is great.',
);
```

Then launch the PayPal request:

```dart
BraintreePaymentMethodNonce result = await Braintree.requestPaypalNonce(
   '<Insert your tokenization key or client token here>',
   request,
);
if (result != null) {
  print('Nonce: ${result.nonce}');
} else {
  print('PayPal flow was canceled.');
}
```

### Braintree's native drop-in

Create a drop-in request object:

```dart
final request = BraintreeDropInRequest(
  clientToken: '<Insert your client token here>',
  collectDeviceData: true,
  googlePaymentRequest: BraintreeGooglePaymentRequest(
    totalPrice: '4.20',
    currencyCode: 'USD',
    billingAddressRequired: false,
  ),
  paypalRequest: BraintreePayPalRequest(
    amount: '4.20',
    displayName: 'Example company',
  ),
);
```

Then launch the drop-in (a `BuildContext` is required as of v6.0.0):

```dart
BraintreeDropInResult? result = await BraintreeDropIn.start(context, request);
```

> On iOS and web this presents a cross-platform Flutter payment sheet (the native iOS Drop-in SDK
> has no Braintree v7 release). On Android it presents the native Drop-in UI.

Access the payment nonce:

```dart
if (result != null) {
  print('Nonce: ${result.paymentMethodNonce.nonce}');
} else {
  print('Selection was canceled.');
}
```

To increase the chances of success with 3DS2 challenge is possible to add additional information about the user
as mentioned in the guide to [Migrate to 3D Secure 2](https://developer.paypal.com/braintree/docs/guides/3d-secure/migration).

```dart
var request = BraintreeDropInRequest(
  clientToken: '<Insert your client token here>',
  collectDeviceData: true,
  requestThreeDSecureVerification: true,
  email: "test@email.com",
  amount: "0,01",
  billingAddress: BraintreeBillingAddress(
    givenName: "Jill",
    surname: "Doe",
    phoneNumber: "5551234567",
    streetAddress: "555 Smith St",
    extendedAddress: "#2",
    locality: "Chicago",
    region: "IL",
    postalCode: "12345",
    countryCodeAlpha2: "US",
  ),
  cardEnabled: true,
);
```

See `BraintreeDropInRequest` and `BraintreeDropInResult` for more documentation.
