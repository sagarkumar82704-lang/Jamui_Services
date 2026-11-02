import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:apna_jamui_provider/provider_app.dart';

/// [ProviderNativeHostScreen]
/// Seamlessly hosts the native Provider Experience directly inside the Customer App.
/// Enables 100% native Phone OTP (with Android SMS Retriever), hardware GPS (Geolocator),
/// KYC camera document uploads, and real-time lead tracking without WebView friction.
class ProviderNativeHostScreen extends StatelessWidget {
  final ProviderRepository? repository;

  const ProviderNativeHostScreen({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    final repo = repository ??
        ProviderRepositoryImpl(
          remoteDataSource: FirebaseProviderRemoteDataSource(),
        );

    return MultiBlocProvider(
      providers: [
        BlocProvider<ProviderAuthBloc>(
          create: (_) => ProviderAuthBloc(providerRepository: repo)..add(CheckAuthStatusEvent()),
        ),
      ],
      child: PopScope(
        canPop: true,
        child: const AuthRouterScreen(),
      ),
    );
  }
}
