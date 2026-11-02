import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/admin_sidebar.dart';
import '../../../../core/widgets/admin_topbar.dart';
import '../../../auth/presentation/bloc/admin_auth_bloc.dart';
import '../../../auth/presentation/bloc/admin_auth_event.dart';
import '../../../auth/presentation/bloc/admin_auth_state.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../../providers/presentation/pages/providers_page.dart';
import '../../../categories/presentation/pages/categories_page.dart';
import '../../../banners/presentation/pages/banners_management_page.dart';
import '../../../services/presentation/pages/services_page.dart';
import '../../../leads/presentation/pages/leads_page.dart';
import '../../../bookings/presentation/pages/bookings_page.dart';
import '../../../subscriptions/presentation/pages/subscriptions_page.dart';
import '../../../payments/presentation/pages/payments_page.dart';
import '../../../reviews/presentation/pages/reviews_page.dart';
import '../../../complaints/presentation/pages/complaints_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../analytics/presentation/pages/analytics_page.dart';
import '../../../ai_insights/presentation/pages/ai_insights_page.dart';
import '../../../admins/presentation/pages/admins_page.dart';
import '../../../professional_admin/presentation/pages/professional_admin_dashboard_page.dart';
import '../../../audit_logs/presentation/pages/audit_logs_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class MainLayoutPage extends StatefulWidget {
  const MainLayoutPage({super.key});

  @override
  State<MainLayoutPage> createState() => _MainLayoutPageState();
}

class _MainLayoutPageState extends State<MainLayoutPage> {
  String _currentRoute = 'dashboard';
  bool _isSidebarCollapsed = false;

  Widget _buildContentPage() {
    switch (_currentRoute) {
      case 'professional_dashboard':
      case 'diamond_dashboard':
        return const ProfessionalAdminDashboardPage();
      case 'dashboard':
        return const DashboardPage();
      case 'customers':
        return const CustomersPage();
      case 'providers':
        return const ProvidersPage();
      case 'categories':
        return const CategoriesPage();
      case 'banners':
        return const BannersManagementPage();
      case 'services':
        return const ServicesPage();
      case 'leads':
        return const LeadsPage();
      case 'bookings':
        return const BookingsPage();
      case 'subscriptions':
        return const SubscriptionsPage();
      case 'payments':
        return const PaymentsPage();
      case 'reviews':
        return const ReviewsPage();
      case 'complaints':
        return const ComplaintsPage();
      case 'notifications':
        return const NotificationsPage();
      case 'analytics':
        return const AnalyticsPage();
      case 'ai_insights':
        return const AiInsightsPage();
      case 'admins':
        return const AdminsPage();
      case 'audit_logs':
        return const AuditLogsPage();
      case 'settings':
        return const SettingsPage();
      default:
        return const DashboardPage();
    }
  }

  String get _currentTitle {
    switch (_currentRoute) {
      case 'professional_dashboard':
      case 'diamond_dashboard':
        return 'Professional (Pro) Operations';
      case 'dashboard':
        return 'Dashboard Overview';
      case 'customers':
        return 'Customer Directory';
      case 'providers':
        return 'Provider KYC & Directory';
      case 'categories':
        return 'Service Categories';
      case 'banners':
        return 'Sponsor Banners & Campaigns';
      case 'services':
        return 'Service Management';
      case 'leads':
        return 'Lead Management';
      case 'bookings':
        return 'Bookings Audit';
      case 'subscriptions':
        return 'Provider Subscriptions';
      case 'payments':
        return 'Payment Transactions';
      case 'reviews':
        return 'Review Moderation';
      case 'complaints':
        return 'Customer Complaints';
      case 'notifications':
        return 'Push Notifications';
      case 'analytics':
        return 'System Analytics';
      case 'ai_insights':
        return 'AI & Predictive Insights';
      case 'admins':
        return 'Admins & Role Control';
      case 'audit_logs':
        return 'Immutable Audit Logs';
      case 'settings':
        return 'System Settings';
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminAuthBloc, AdminAuthState>(
      builder: (context, authState) {
        String email = 'admin@jamuiservice.com';
        if (authState is AdminAuthenticated) {
          email = authState.adminUser.email;
        }

        final isDesktop = ResponsiveLayout.isDesktop(context);

        return Scaffold(
          backgroundColor: AppColors.background,
          drawer: !isDesktop
              ? Drawer(
                  child: AdminSidebar(
                    currentRoute: _currentRoute,
                    onSelectRoute: (route) {
                      setState(() => _currentRoute = route);
                      Navigator.pop(context);
                    },
                  ),
                )
              : null,
          body: Row(
            children: [
              if (isDesktop)
                AdminSidebar(
                  currentRoute: _currentRoute,
                  isCollapsed: _isSidebarCollapsed,
                  onSelectRoute: (route) {
                    setState(() => _currentRoute = route);
                  },
                ),
              Expanded(
                child: Column(
                  children: [
                    AdminTopbar(
                      title: _currentTitle,
                      adminEmail: email,
                      onToggleSidebar: () {
                        if (isDesktop) {
                          setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
                        } else {
                          Scaffold.of(context).openDrawer();
                        }
                      },
                      onLogout: () {
                        context.read<AdminAuthBloc>().add(LogoutEvent());
                      },
                    ),
                    Expanded(
                      child: SelectionArea(
                        child: _buildContentPage(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
