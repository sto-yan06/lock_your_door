import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/lock_session_controller.dart';

class MenuView extends StatelessWidget {
  const MenuView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF663399),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 40,
                ),
                SizedBox(height: 8),
                Text(
                  "Settings",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Customize your door security",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Settings Options
          _buildSettingCard(
            icon: Icons.notifications,
            title: "Notifications",
            subtitle: "Manage door lock reminders",
            onTap: () => _showNotificationSettings(context),
          ),
          
          const SizedBox(height: 12),
          
          _buildSettingCard(
            icon: Icons.history,
            title: "Lock History",
            subtitle: "View recent door activities",
            onTap: () => _showLockHistory(context),
          ),
          
          const SizedBox(height: 12),
          
          _buildSettingCard(
            icon: Icons.security,
            title: "Security",
            subtitle: "Security and privacy settings",
            onTap: () => _showSecuritySettings(context),
          ),
          
          const SizedBox(height: 12),
          
          _buildSettingCard(
            icon: Icons.delete_forever,
            title: "Clear Data",
            subtitle: "Reset all app data",
            onTap: () => _showClearDataDialog(context),
            isDestructive: true,
          ),
          
          const SizedBox(height: 12),
          
          _buildSettingCard(
            icon: Icons.info,
            title: "About",
            subtitle: "App version and information",
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDestructive 
                        ? Colors.red.withValues(alpha: 0.1)
                        : const Color(0xFF663399).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive ? Colors.red : const Color(0xFF663399),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDestructive ? Colors.red : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notification Settings'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Configure your door lock reminder notifications.'),
              SizedBox(height: 16),
              // Add notification toggles here
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showLockHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Lock History'),
          content: const Text('Your recent door lock activities will appear here.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showSecuritySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Security Settings'),
          content: const Text('Security and privacy options will be available here.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Data'),
          content: const Text('This will permanently delete all your door lock data. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final controller = Provider.of<LockSessionController>(context, listen: false);
                await controller.clearAllData();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared successfully')),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear Data'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Lock Your Door',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.lock, size: 48, color: Color(0xFF663399)),
      children: const [
        Text('A simple and secure door lock monitoring app.'),
        SizedBox(height: 8),
        Text('Keep track of your door security with photo verification.'),
      ],
    );
  }
}