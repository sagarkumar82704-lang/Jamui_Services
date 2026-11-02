import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/customer_auth_bloc.dart';
import '../../../auth/presentation/bloc/customer_auth_event.dart';
import '../../../auth/presentation/bloc/customer_auth_state.dart';
import '../../../auth/presentation/pages/customer_login_screen.dart';
import '../../../auth/presentation/pages/customer_profile_setup_screen.dart';
import '../../../bookings/presentation/pages/customer_bookings_screen.dart';
import '../../../discovery/presentation/pages/all_categories_page.dart';
import '../../../profile/presentation/pages/customer_profile_page.dart';
import 'customer_home_screen.dart';

class CustomerMainShell extends StatefulWidget {
  const CustomerMainShell({super.key});

  @override
  State<CustomerMainShell> createState() => _CustomerMainShellState();
}

class _CustomerMainShellState extends State<CustomerMainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    CustomerHomeScreen(),
    AllCategoriesPage(isEmbedded: true),
    CustomerBookingsScreen(),
    CustomerProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthGuard();
    });
  }

  void _checkAuthGuard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerLoginScreen()),
        (route) => false,
      );
    } else if (user != null && mounted) {
      final authBloc = context.read<CustomerAuthBloc>();
      if (authBloc.state is! CustomerAuthenticatedState) {
        authBloc.add(const CheckCustomerAuthStatusEvent());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CustomerAuthBloc, CustomerAuthState>(
      listener: (context, state) {
        if (state is CustomerUnauthenticatedState) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const CustomerLoginScreen()),
            (route) => false,
          );
        } else if (state is CustomerProfileSetupRequiredState) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerProfileSetupScreen(
                userId: state.userId,
                email: state.email,
                phoneNumber: state.phoneNumber,
              ),
            ),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.miscellaneous_services_outlined),
              activeIcon: Icon(Icons.miscellaneous_services_rounded),
              label: 'Services',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment_rounded),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
