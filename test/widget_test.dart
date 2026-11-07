import 'package:flutter_test/flutter_test.dart';
import 'package:deliv_track/main.dart';
import 'package:deliv_track/common_widgets/app_logo.dart';
import 'package:deliv_track/common_widgets/brand_loading_indicator.dart';

void main() {
  testWidgets('DelivTrackApp Splash Screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DelivTrackApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Parcel & Payment Manager'), findsOneWidget);
    expect(find.byType(BrandLoadingIndicator), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
  });
}
