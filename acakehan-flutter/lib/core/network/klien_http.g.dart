// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'klien_http.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$penyimpananAmanHash() => r'ee609cbaaeae4f7be1f4dc87b05f9c795acf4302';

/// Provider untuk FlutterSecureStorage — singleton di seluruh app.
///
/// Copied from [penyimpananAman].
@ProviderFor(penyimpananAman)
final penyimpananAmanProvider =
    AutoDisposeProvider<FlutterSecureStorage>.internal(
  penyimpananAman,
  name: r'penyimpananAmanProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$penyimpananAmanHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PenyimpananAmanRef = AutoDisposeProviderRef<FlutterSecureStorage>;
String _$klienHttpHash() => r'112402374035d1d7938758c630a4e9abdfac1da8';

/// Provider untuk instance Dio yang sudah dikonfigurasi penuh.
///
/// Copied from [klienHttp].
@ProviderFor(klienHttp)
final klienHttpProvider = AutoDisposeProvider<Dio>.internal(
  klienHttp,
  name: r'klienHttpProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$klienHttpHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef KlienHttpRef = AutoDisposeProviderRef<Dio>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
