import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/features/auth/presentation/bloc/provider_auth_bloc.dart';
import 'package:apna_jamui_provider/features/auth/presentation/pages/provider_login_page.dart';
import 'features/auth/provider_auth_bloc_test.dart';

void main() {
  testWidgets('Provider app renders login screen when unauthenticated', (WidgetTester tester) async {
    final mockRepo = MockProviderRepository(currentProfile: null);
    final bloc = ProviderAuthBloc(providerRepository: mockRepo);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ProviderAuthBloc>.value(
          value: bloc,
          child: const ProviderLoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jamui Services'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
