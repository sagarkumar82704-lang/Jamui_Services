import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// [AppBlocObserver] सभी BLoC/Cubit के स्टेट बदलावों और एरर्स को कंसोल पर लॉग करता है।
/// इससे डीबगिंग बहुत आसान और पारदर्शी हो जाती है।
class AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (kDebugMode) {
      debugPrint('🟢 [BLoC Created]: ${bloc.runtimeType}');
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      debugPrint('🔄 [BLoC State Change] ${bloc.runtimeType}: ${change.currentState} ➔ ${change.nextState}');
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('🔴 [BLoC Error] ${bloc.runtimeType}: $error');
    }
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (kDebugMode) {
      debugPrint('⚪ [BLoC Closed]: ${bloc.runtimeType}');
    }
  }
}
