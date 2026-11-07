import 'package:flutter_test/flutter_test.dart';
import 'package:deliv_track/main.dart';
import 'package:deliv_track/common_widgets/app_logo.dart';
import 'package:deliv_track/common_widgets/brand_loading_indicator.dart';
import 'helpers/fake_auth_repository.dart';

void main() {
  testWidgets('DelivTrackApp Splash Screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(DelivTrackApp(repository: FakeAuthRepository()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Parcel & Payment Manager'), findsOneWidget);
    expect(find.byType(BrandLoadingIndicator), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
  });
}
