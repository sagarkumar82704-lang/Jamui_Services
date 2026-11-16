import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../auth/domain/entities/provider_profile_entity.dart';
import '../../data/datasources/firebase_lead_remote_data_source.dart';
import '../../data/repositories/lead_repository_impl.dart';
import '../../domain/entities/lead_entity.dart';
import '../bloc/lead_bloc.dart';
import '../bloc/lead_event.dart';
import '../bloc/lead_state.dart';
import '../widgets/incoming_lead_alert_modal.dart';

class LeadsPage extends StatefulWidget {
  final ProviderProfileEntity profile;

  const LeadsPage({super.key, required this.profile});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _notifiedLeadIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkIncomingLeads(BuildContext context, List<LeadEntity> leads) {
    final newLeads = leads.where((l) => l.status == LeadStatus.newLead).toList();
    for (final lead in newLeads) {
      if (!_notifiedLeadIds.contains(lead.id)) {
        _notifiedLeadIds.add(lead.id);

        // Auto mark as viewed
        context.read<LeadBloc>().add(
              UpdateLeadStatusEvent(leadId: lead.id, newStatus: LeadStatus.viewed),
            );

        // Show Full Screen Ringing Alert
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            IncomingLeadAlertModal.show(
              context,
              lead: lead,
              onAccept: () {
                context.read<LeadBloc>().add(
                      UpdateLeadStatusEvent(leadId: lead.id, newStatus: LeadStatus.accepted),
                    );
              },
              onReject: () {
                context.read<LeadBloc>().add(
                      UpdateLeadStatusEvent(leadId: lead.id, newStatus: LeadStatus.rejected),
                    );
              },
            );
          }
        });
        break; // Show one at a time
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LeadBloc>(
      create: (_) => LeadBloc(
        leadRepository: LeadRepositoryImpl(
          remoteDataSource: FirebaseLeadRemoteDataSource(),
        ),
      )..add(SubscribeLeadsEvent(widget.profile.id)),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('ग्राहक लीड्स एवं इनक्वायरी', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: ResponsiveLayout.isSmallMobile(context),
            tabAlignment: ResponsiveLayout.isSmallMobile(context)
                ? TabAlignment.start
                : TabAlignment.fill,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.accent,
            tabs: const [
              Tab(text: 'नई इनक्वायरी'),
              Tab(text: 'स्वीकृत'),
              Tab(text: 'संपूर्ण'),
              Tab(text: 'सभी'),
            ],
          ),
        ),
        body: BlocConsumer<LeadBloc, LeadState>(
          listener: (context, state) {
            if (state is LeadsLoaded) {
              _checkIncomingLeads(context, state.leads);
            }
          },
          builder: (context, state) {
            if (state is LeadLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.accent));
            }

            if (state is LeadError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }

            if (state is LeadsLoaded) {
              final allLeads = state.leads;
              final hasReachedMax = state.hasReachedMax;

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildLeadList(
                    context,
                    allLeads.where((l) => l.status == LeadStatus.newLead || l.status == LeadStatus.viewed).toList(),
                    'कोई नई इनक्वायरी नहीं है।',
                    hasReachedMax: hasReachedMax,
                  ),
                  _buildLeadList(
                    context,
                    allLeads.where((l) => l.status == LeadStatus.accepted).toList(),
                    'कोई स्वीकृत लीड नहीं है।',
                    hasReachedMax: hasReachedMax,
                  ),
                  _buildLeadList(
                    context,
                    allLeads.where((l) => l.status == LeadStatus.completed).toList(),
                    'कोई पूर्ण कार्य नहीं है।',
                    hasReachedMax: hasReachedMax,
                  ),
                  _buildLeadList(
                    context,
                    allLeads,
                    'कोई लीड्स प्राप्त नहीं हुई हैं।',
                    hasReachedMax: hasReachedMax,
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLeadList(
    BuildContext context,
    List<LeadEntity> leads,
    String emptyMessage, {
    bool hasReachedMax = true,
  }) {
    if (leads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_rounded, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(emptyMessage, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
            if (!hasReachedMax) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('और पुरानी लीड्स लोड करें'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  context.read<LeadBloc>().add(const LoadMoreLeadsEvent());
                },
              ),
            ],
          ],
        ),
      );
    }

    final showLoadMore = !hasReachedMax;

    return SingleChildScrollView(
      child: ResponsiveContentContainer(
        padding: ResponsiveLayout.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveCardGrid(
              tabletColumns: 2,
              desktopColumns: 2,
              largeDesktopColumns: 3,
              spacing: 14,
              runSpacing: 0,
              children: leads.map((lead) => _buildLeadCard(context, lead)).toList(),
            ),
            if (showLoadMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('और पुरानी लीड्स लोड करें'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      context.read<LeadBloc>().add(const LoadMoreLeadsEvent());
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadCard(BuildContext context, LeadEntity lead) {
    Color statusBg = Colors.grey.shade100;
    Color statusText = Colors.grey.shade800;

    switch (lead.status) {
      case LeadStatus.newLead:
        statusBg = Colors.amber.withValues(alpha: 0.15);
        statusText = Colors.amber.shade900;
        break;
      case LeadStatus.accepted:
        statusBg = Colors.blue.withValues(alpha: 0.15);
        statusText = Colors.blue.shade900;
        break;
      case LeadStatus.completed:
        statusBg = Colors.green.withValues(alpha: 0.15);
        statusText = Colors.green.shade900;
        break;
      case LeadStatus.rejected:
      case LeadStatus.cancelled:
        statusBg = Colors.red.withValues(alpha: 0.15);
        statusText = Colors.red.shade900;
        break;
      default:
        break;
    }

    final formattedTime = '${lead.createdAt.day}/${lead.createdAt.month}/${lead.createdAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  lead.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lead.status.displayNameHindi,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lead.serviceName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.accent),
          ),
          if (lead.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              lead.description,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  lead.address,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                formattedTime,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
          const Divider(height: 20),

          // Actions
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lead.customerPhone.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.phone_in_talk, color: AppColors.info, size: 20),
                      tooltip: 'फोन कॉल करें',
                      onPressed: () => _makePhoneCall(lead.customerPhone),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                      tooltip: 'व्हाट्सएप चैट',
                      onPressed: () => _openWhatsApp(lead.customerPhone),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (lead.status == LeadStatus.newLead) ...[
                    OutlinedButton(
                      onPressed: () {
                        context.read<LeadBloc>().add(
                              UpdateLeadStatusEvent(leadId: lead.id, newStatus: LeadStatus.rejected),
                            );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: const Text('अस्वीकार', style: TextStyle(fontSize: 11)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        context.read<LeadBloc>().add(
                              UpdateLeadStatusEvent(leadId: lead.id, newStatus: LeadStatus.accepted),
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      ),
                      child: const Text('स्वीकार करें', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  if (lead.status == LeadStatus.accepted)
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<LeadBloc>().add(
                              UpdateLeadStatusEvent(leadId: lead.id, newStatus: LeadStatus.completed),
                            );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('कार्य पूर्ण (Mark Done)', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
