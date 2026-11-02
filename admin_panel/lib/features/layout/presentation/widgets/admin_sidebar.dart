import 'package:flutter/material.dart';
import '../../../../core/constants/admin_colors.dart';
import '../../../auth/domain/entities/admin_user_entity.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final AdminUserEntity admin;
  final VoidCallback onLogout;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.admin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AdminColors.sidebarBackground,
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Brand Header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: AdminColors.sidebarHeader,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AdminColors.accentEmerald,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.layers_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'JAMUI SERVICE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'मास्टर एडमिन पोर्टल',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.accentEmeraldLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildSectionHeader('मुख्य संचालन'),
                _buildMenuItem(0, Icons.pie_chart_outline_rounded, 'डैशबोर्ड एवं मेट्रिक्स'),
                _buildMenuItem(1, Icons.verified_user_outlined, 'प्रोवाइडर्स एवं KYC'),
                _buildMenuItem(2, Icons.people_outline_rounded, 'ग्राहक (Customers)'),
                
                const SizedBox(height: 12),
                _buildSectionHeader('सेवाएं एवं व्यापार'),
                _buildMenuItem(3, Icons.category_outlined, 'श्रेणियाँ (Categories)'),
                _buildMenuItem(4, Icons.miscellaneous_services_rounded, 'सर्विसेज कैटलॉग'),
                _buildMenuItem(5, Icons.card_membership_rounded, 'सब्सक्रिप्शन व प्लान्स'),
                _buildMenuItem(6, Icons.phone_in_talk_rounded, 'डायरेक्ट लीड्स'),
                _buildMenuItem(7, Icons.receipt_long_rounded, 'बुकिंग्स हिस्ट्री'),

                const SizedBox(height: 12),
                _buildSectionHeader('सुरक्षा एवं सिस्टम'),
                _buildMenuItem(8, Icons.security_rounded, 'ऑडिट लॉग्स (Audit)'),
                _buildMenuItem(9, Icons.settings_outlined, 'सिस्टम सेटिंग्स'),
              ],
            ),
          ),

          // Sidebar Footer (Admin Profile & Logout)
          Container(
            padding: const EdgeInsets.all(16),
            color: AdminColors.sidebarHeader,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF334155),
                  child: Text(
                    admin.name.isNotEmpty ? admin.name[0].toUpperCase() : 'A',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        admin.name,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        admin.role.displayNameHindi,
                        style: const TextStyle(fontSize: 10.5, color: AdminColors.accentEmeraldLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AdminColors.textMuted, size: 18),
                  tooltip: 'लॉगआउट',
                  onPressed: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => onItemSelected(index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AdminColors.sidebarActive : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
