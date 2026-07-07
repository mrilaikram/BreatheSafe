import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/background_alert_service.dart';
import '../services/profile_service.dart';
import '../services/ble_sensor_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  final ProfileService profileService;
  final BleSensorService bleService;

  const SettingsScreen({
    super.key,
    required this.profileService,
    required this.bleService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _updateBackgroundAlerts({
    bool? enabled,
    int? snoozeMinutes,
  }) async {
    await widget.profileService.updateBackgroundAlerts(
      enabled: enabled,
      snoozeMinutes: snoozeMinutes,
    );
    await BackgroundAlertService.configureFromProfile(widget.profileService);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profileService.profile;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: 'Personal Profile',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _ProfileCard(
                profile: profile,
                onEdit: () {
                  Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRoutes.onboarding);
                },
              ),
              const SizedBox(height: 32),
              _SectionTitle(title: 'IoT Device Connectivity', icon: Icons.wifi),
              const SizedBox(height: 16),
              _DevicePanel(bleService: widget.bleService),
              const SizedBox(height: 32),
              _SectionTitle(
                title: 'Background Alerts',
                icon: Icons.notifications_active_outlined,
              ),
              const SizedBox(height: 16),
              _AlertSettingsCard(
                enabled: widget.profileService.backgroundAlertsEnabled,
                snoozeMinutes: widget.profileService.alertSnoozeMinutes,
                onEnabledChanged: (value) {
                  _updateBackgroundAlerts(enabled: value);
                },
                onSnoozeChanged: (value) {
                  _updateBackgroundAlerts(snoozeMinutes: value);
                },
              ),
              const SizedBox(height: 16),
              _AlarmTriggerGuideCard(profile: profile),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEdit;

  const _ProfileCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Age Group',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  profile.ageGroup?.icon,
                  size: 24,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  profile.ageGroup?.label ?? 'Not set',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Health Conditions',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (profile.conditions.isEmpty)
              Text(
                'None selected',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textTertiary,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    profile.conditions.map((condition) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          condition.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _DevicePanel extends StatelessWidget {
  final BleSensorService bleService;

  const _DevicePanel({required this.bleService});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<bool>(
              stream: bleService.connectionStateStream,
              initialData: bleService.isConnected,
              builder: (context, connectionSnapshot) {
                final isConnected = connectionSnapshot.data ?? false;
                
                if (isConnected) {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.bluetooth_connected,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bleService.connectedDeviceName ?? 'BreatheSafe_Device',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Connected to background service',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle, color: AppColors.safeGreen),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => bleService.disconnect(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.dangerRed,
                            side: const BorderSide(color: AppColors.dangerRed),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Disconnect'),
                        ),
                      ),
                    ],
                  );
                }

                return StreamBuilder<bool>(
                  stream: bleService.scanStateStream,
                  initialData: bleService.isScanning,
                  builder: (context, scanStateSnapshot) {
                    final isScanning = scanStateSnapshot.data ?? false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: isScanning
                              ? () => bleService.stopScan()
                              : () => bleService.startScan(),
                          icon: isScanning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(isScanning ? 'Scanning...' : 'Search for Devices'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isScanning ? AppColors.moderateYellow : AppColors.primaryGreen,
                            foregroundColor: isScanning ? AppColors.textPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<BleScanDevice>>(
                          stream: bleService.scanDevicesStream,
                          initialData: bleService.scanDevices,
                          builder: (context, scanSnapshot) {
                            final devices = scanSnapshot.data ?? [];
                            
                            if (devices.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.bluetooth_searching,
                                      size: 48,
                                      color: AppColors.textTertiary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      isScanning ? 'Searching...' : 'No devices found',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Container(
                              constraints: const BoxConstraints(maxHeight: 250),
                              decoration: BoxDecoration(
                                color: AppColors.bgWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: devices.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final device = devices[index];
                                  return ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: device.isBreatheSafe
                                            ? AppColors.primaryGreen.withValues(alpha: 0.1)
                                            : AppColors.bgGray,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.bluetooth,
                                        color: device.isBreatheSafe
                                            ? AppColors.primaryGreen
                                            : AppColors.textTertiary,
                                      ),
                                    ),
                                    title: Text(
                                      device.displayName,
                                      style: GoogleFonts.inter(
                                        fontWeight: device.isBreatheSafe
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'RSSI: ${device.rssi} dBm',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    trailing: TextButton(
                                      onPressed: () => bleService.connectToScannedDevice(device),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primaryGreen,
                                      ),
                                      child: const Text('Connect'),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              }
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertSettingsCard extends StatelessWidget {
  final bool enabled;
  final int snoozeMinutes;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onSnoozeChanged;

  const _AlertSettingsCard({
    required this.enabled,
    required this.snoozeMinutes,
    required this.onEnabledChanged,
    required this.onSnoozeChanged,
  });

  @override
  Widget build(BuildContext context) {
    const snoozeOptions = [5, 10, 15, 30, 60];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: onEnabledChanged,
              activeThumbColor: AppColors.primaryGreen,
              title: Text(
                'Run background monitor',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Keeps BLE auto-connect and unsafe-air alerts active.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Alert snooze time',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                DropdownButton<int>(
                  value: snoozeOptions.contains(snoozeMinutes)
                      ? snoozeMinutes
                      : 15,
                  dropdownColor: AppColors.cardSurface,
                  items: snoozeOptions.map((minutes) {
                    return DropdownMenuItem<int>(
                      value: minutes,
                      child: Text('$minutes min'),
                    );
                  }).toList(),
                  onChanged: enabled
                      ? (value) {
                          if (value != null) onSnoozeChanged(value);
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'When an alert appears, OK pauses more warnings for this time.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmTriggerGuideCard extends StatelessWidget {
  final UserProfile profile;

  const _AlarmTriggerGuideCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final hasRespiratory = profile.conditions.any((c) =>
        c == RespiratoryCondition.asthma ||
        c == RespiratoryCondition.chronicWheezing ||
        c == RespiratoryCondition.dustAllergy);
    final isSensitiveAge =
        profile.ageGroup == AgeGroup.child || profile.ageGroup == AgeGroup.senior;

    String dustThreshold;
    String? humidityThreshold;
    String profileReason;

    if (hasRespiratory) {
      dustThreshold = 'Above 35 μg/m³';
      humidityThreshold = 'Above 65% or Below 35%';
      profileReason = 'Because you have respiratory conditions selected.';
    } else if (isSensitiveAge) {
      dustThreshold = 'Above 35 μg/m³';
      humidityThreshold = 'Above 70% or Below 30%';
      profileReason = 'Because your age group is sensitive to poor air.';
    } else {
      dustThreshold = 'Above 55 μg/m³';
      humidityThreshold = null;
      profileReason = 'Standard safe limits for healthy adults.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'When will the alarm trigger?',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              profileReason,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildThresholdRow('Dust Density', dustThreshold, AppColors.primaryGreen),
                  if (humidityThreshold != null) ...[
                    const Divider(height: 16),
                    _buildThresholdRow('Humidity', humidityThreshold, AppColors.humidityBlue),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdRow(String label, String threshold, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          threshold,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
