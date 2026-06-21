import 'dart:async';
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
  bool _isSearching = false;
  List<BleScanDevice> _scanDevices = const [];
  String? _scanMessage;
  StreamSubscription<bool>? _scanStateSubscription;
  StreamSubscription<List<BleScanDevice>>? _scanDevicesSubscription;
  StreamSubscription<String?>? _scanMessageSubscription;

  @override
  void initState() {
    super.initState();
    _isSearching = widget.bleService.isScanning;
    _scanDevices = widget.bleService.scanDevices;

    _scanStateSubscription = widget.bleService.scanStateStream.listen((state) {
      if (mounted) {
        setState(() => _isSearching = state);
      }
    });

    _scanDevicesSubscription = widget.bleService.scanDevicesStream.listen((
      devices,
    ) {
      if (mounted) {
        setState(() => _scanDevices = devices);
      }
    });

    _scanMessageSubscription = widget.bleService.scanMessageStream.listen((
      message,
    ) {
      if (mounted) {
        setState(() => _scanMessage = message);
      }
    });
  }

  @override
  void dispose() {
    _scanStateSubscription?.cancel();
    _scanDevicesSubscription?.cancel();
    _scanMessageSubscription?.cancel();
    super.dispose();
  }

  void _searchDevice() async {
    if (_isSearching) return;
    await widget.bleService.startScan();
  }

  void _stopSearch() async {
    await widget.bleService.stopScan();
  }

  void _connectDevice(BleScanDevice device) async {
    await widget.bleService.connectToScannedDevice(device);
  }

  void _disconnectDevice() async {
    await widget.bleService.disconnect();
  }

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
              StreamBuilder<bool>(
                stream: widget.bleService.connectionStateStream,
                initialData: widget.bleService.isConnected,
                builder: (context, snapshot) {
                  final isConnected = snapshot.data ?? false;
                  return _DevicePanel(
                    isSearching: _isSearching,
                    deviceFound: isConnected,
                    deviceName:
                        widget.bleService.connectedDevice?.platformName ??
                        'BreatheSafe_Device',
                    scanDevices: _scanDevices,
                    scanMessage: _scanMessage,
                    onSearch: _searchDevice,
                    onStopSearch: _stopSearch,
                    onConnectDevice: _connectDevice,
                    onDisconnect: _disconnectDevice,
                  );
                },
              ),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            Text(
              'Conditions',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.conditions.map((c) {
                return Chip(
                  label: Text(c.label),
                  avatar: Icon(c.icon, size: 16, color: AppColors.primaryGreen),
                  backgroundColor: AppColors.primaryGreen.withValues(
                    alpha: 0.1,
                  ),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryGreen,
                  ),
                  side: BorderSide.none,
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
  final bool isSearching;
  final bool deviceFound;
  final String deviceName;
  final List<BleScanDevice> scanDevices;
  final String? scanMessage;
  final VoidCallback onSearch;
  final VoidCallback onStopSearch;
  final ValueChanged<BleScanDevice> onConnectDevice;
  final VoidCallback onDisconnect;

  const _DevicePanel({
    required this.isSearching,
    required this.deviceFound,
    required this.deviceName,
    required this.scanDevices,
    required this.scanMessage,
    required this.onSearch,
    required this.onStopSearch,
    required this.onConnectDevice,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (scanMessage != null) ...[
              _ScanMessage(message: scanMessage!),
              const SizedBox(height: 16),
            ],
            if (!deviceFound && !isSearching) ...[
              const Icon(
                Icons.bluetooth_searching,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'No device connected',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search),
                label: const Text('Search for BreatheSafe Device'),
              ),
              if (scanDevices.isNotEmpty) ...[
                const SizedBox(height: 20),
                _ScanResultList(
                  devices: scanDevices,
                  onConnectDevice: onConnectDevice,
                ),
              ],
            ],
            if (isSearching) ...[
              const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 16),
              Text(
                'Scanning for Bluetooth devices...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onStopSearch,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Stop Search'),
              ),
              if (scanDevices.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ScanResultList(
                  devices: scanDevices,
                  onConnectDevice: onConnectDevice,
                ),
              ],
            ],
            if (deviceFound && !isSearching) ...[
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
                            deviceName.isNotEmpty
                                ? deviceName
                                : 'BreatheSafe_Device',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connected',
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
              TextButton.icon(
                onPressed: onDisconnect,
                icon: const Icon(Icons.bluetooth_disabled, size: 18),
                label: const Text('Disconnect'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.dangerRed,
                ),
              ),
            ],
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

class _ScanMessage extends StatelessWidget {
  final String message;

  const _ScanMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.moderateYellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.moderateYellow.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.moderateYellow,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanResultList extends StatelessWidget {
  final List<BleScanDevice> devices;
  final ValueChanged<BleScanDevice> onConnectDevice;

  const _ScanResultList({required this.devices, required this.onConnectDevice});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Available BLE devices',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...devices.take(8).map((device) {
          final color = device.isBreatheSafe
              ? AppColors.primaryGreen
              : AppColors.textTertiary;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onConnectDevice(device),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bluetooth, color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${device.remoteId}  RSSI ${device.rssi}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (device.isBreatheSafe)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primaryGreen,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
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

    String purityThreshold;
    String? humidityThreshold;
    String profileReason;

    if (hasRespiratory) {
      purityThreshold = 'Below 85%';
      humidityThreshold = 'Above 65% or Below 35%';
      profileReason = 'Because you have respiratory conditions selected.';
    } else if (isSensitiveAge) {
      purityThreshold = 'Below 80%';
      humidityThreshold = 'Above 70% or Below 30%';
      profileReason = 'Because your age group is sensitive to poor air.';
    } else {
      purityThreshold = 'Below 70%';
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
                  _buildThresholdRow('Air Purity', purityThreshold, AppColors.primaryGreen),
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
