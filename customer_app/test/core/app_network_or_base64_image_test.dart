import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_customer/core/widgets/app_network_or_base64_image.dart';

void main() {
  group('AppNetworkOrBase64Image Unit & Widget Tests', () {
    testWidgets('1. Empty image URL renders fallback broken_image or calls errorBuilder', (tester) async {
      bool errorBuilderCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppNetworkOrBase64Image(
              imageUrl: '   ',
              errorBuilder: (ctx, err, stack) {
                errorBuilderCalled = true;
                return const Text('Fallback Error');
              },
            ),
          ),
        ),
      );

      expect(errorBuilderCalled, isTrue);
      expect(find.text('Fallback Error'), findsOneWidget);
    });

    testWidgets('2. Valid Base64 data URI decodes and renders Image.memory', (tester) async {
      // 1x1 transparent PNG encoded in base64
      const transparent1x1Png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkOrBase64Image(
              imageUrl: transparent1x1Png,
              width: 50,
              height: 50,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('3. Square HTTP image picks width as major dimension and leaves height null to preserve aspect ratio', (tester) async {
      const testUrl = 'https://firebasestorage.googleapis.com/v0/b/jamui/o/avatar.jpg?alt=media&token=test-token-123';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkOrBase64Image(
              imageUrl: testUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );

      final cachedImageFinder = find.byType(CachedNetworkImage);
      expect(cachedImageFinder, findsOneWidget);

      final cachedImageWidget = tester.widget<CachedNetworkImage>(cachedImageFinder);
      expect(cachedImageWidget.imageUrl, equals(testUrl));
      expect(cachedImageWidget.width, equals(48));
      expect(cachedImageWidget.height, equals(48));
      expect(cachedImageWidget.fit, equals(BoxFit.cover));
      // Major dimension: width >= height -> memCacheWidth is 48 * 2.5 = 120, height is null to prevent squashing
      expect(cachedImageWidget.memCacheWidth, equals(120));
      expect(cachedImageWidget.memCacheHeight, isNull);
    });

    testWidgets('4. Tall non-square image (height > width) picks height as major dimension', (tester) async {
      const testUrl = 'https://firebasestorage.googleapis.com/v0/b/jamui/o/poster.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkOrBase64Image(
              imageUrl: testUrl,
              width: 100,
              height: 200,
            ),
          ),
        ),
      );

      final cachedImageFinder = find.byType(CachedNetworkImage);
      final cachedImageWidget = tester.widget<CachedNetworkImage>(cachedImageFinder);
      // Height (200) > Width (100) -> memCacheHeight is 200 * 2.5 = 500, memCacheWidth is null
      expect(cachedImageWidget.memCacheHeight, equals(500));
      expect(cachedImageWidget.memCacheWidth, isNull);
    });

    testWidgets('5. Wide non-square image (width > height) picks width as major dimension', (tester) async {
      const testUrl = 'https://firebasestorage.googleapis.com/v0/b/jamui/o/landscape.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkOrBase64Image(
              imageUrl: testUrl,
              width: 300,
              height: 150,
            ),
          ),
        ),
      );

      final cachedImageFinder = find.byType(CachedNetworkImage);
      final cachedImageWidget = tester.widget<CachedNetworkImage>(cachedImageFinder);
      // Width (300) > Height (150) -> memCacheWidth is 300 * 2.5 = 750, memCacheHeight is null
      expect(cachedImageWidget.memCacheWidth, equals(750));
      expect(cachedImageWidget.memCacheHeight, isNull);
    });

    testWidgets('6. Infinite width (double.infinity) safely leaves memCacheWidth null and sets height', (tester) async {
      const testUrl = 'https://firebasestorage.googleapis.com/v0/b/jamui/o/workplace.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkOrBase64Image(
              imageUrl: testUrl,
              width: double.infinity,
              height: 180,
            ),
          ),
        ),
      );

      final cachedImageFinder = find.byType(CachedNetworkImage);
      expect(cachedImageFinder, findsOneWidget);

      final cachedImageWidget = tester.widget<CachedNetworkImage>(cachedImageFinder);
      expect(cachedImageWidget.memCacheWidth, isNull);
      expect(cachedImageWidget.memCacheHeight, equals((180 * 2.5).round()));
    });

    testWidgets('7. Unbounded dimensions (null) leave both memCacheWidth and memCacheHeight null (Full zoom preservation)', (tester) async {
      const testUrl = 'https://firebasestorage.googleapis.com/v0/b/jamui/o/zoom_full.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkOrBase64Image(
              imageUrl: testUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );

      final cachedImageFinder = find.byType(CachedNetworkImage);
      final cachedImageWidget = tester.widget<CachedNetworkImage>(cachedImageFinder);
      expect(cachedImageWidget.memCacheWidth, isNull);
      expect(cachedImageWidget.memCacheHeight, isNull);
    });

    testWidgets('8. Zero or negative dimensions safely evaluate to null without exceptions', (tester) async {
      const testUrl = 'https://firebasestorage.googleapis.com/v0/b/jamui/o/invalid_dims.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkOrBase64Image(
              imageUrl: testUrl,
              width: 0,
              height: -10,
            ),
          ),
        ),
      );

      final cachedImageFinder = find.byType(CachedNetworkImage);
      final cachedImageWidget = tester.widget<CachedNetworkImage>(cachedImageFinder);
      expect(cachedImageWidget.memCacheWidth, isNull);
      expect(cachedImageWidget.memCacheHeight, isNull);
    });

    testWidgets('9. Explicit caller overrides for memCacheWidth/Height are respected', (tester) async {
      const testUrl = 'https://firebasestorage.googleapis.com/v0/b/jamui/o/override.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkOrBase64Image(
              imageUrl: testUrl,
              width: 100,
              height: 100,
              memCacheWidth: 64,
              memCacheHeight: 64,
            ),
          ),
        ),
      );

      final cachedImageFinder = find.byType(CachedNetworkImage);
      final cachedImageWidget = tester.widget<CachedNetworkImage>(cachedImageFinder);
      expect(cachedImageWidget.memCacheWidth, equals(64));
      expect(cachedImageWidget.memCacheHeight, equals(64));
    });
  });
}
