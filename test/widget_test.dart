import 'package:flutter_test/flutter_test.dart';
import 'package:myframe/main.dart';
import 'package:myframe/settings/app_settings.dart';
import 'package:myframe/widgets/main_shell.dart';

void main() {
  testWidgets('app builds with main shell', (WidgetTester tester) async {
    final settings = AppSettings();
    await settings.load();
    await tester.pumpWidget(MyFrameApp(settings: settings));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MainShell), findsOneWidget);
  });
}
