import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/ble_sensor_service.dart';
import '../widgets/air_purity_ring.dart';
import '../widgets/scan_button.dart';
import '../widgets/mini_telemetry_ring.dart';
import '../widgets/sparkline_chart.dart';

class HomeScreen extends StatefulWidget {
  final BleSensorService bleService;
  final ProfileService profileService;

  const HomeScreen({
    super.key,
    required this.bleService,
    required this.profileService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  SensorData? _latestData;
  bool _isScanning = false;
  late AnimationController _headerGlowController;
  late Animation<double> _headerGlow;
  StreamSubscription<SensorData>? _sensorSubscription;

  @override
  void initState() {
    super.initState();
    _headerGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _headerGlow = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _headerGlowController, curve: Curves.easeInOut),
    );

    _sensorSubscription = widget.bleService.sensorStream.listen((data) {
      if (mounted) {
        setState(() => _latestData = data);
      }
    });
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _headerGlowController.dispose();
    super.dispose();
  }

  void _handleScan() {
    // The background service now handles all BLE connections automatically.
    // We just show a quick toast or UI feedback if they tap it anyway.
    setState(() => _isScanning = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }

  // --- HEALTH LOGIC ---
  bool _hasRespiratoryCondition() {
    final conditions = widget.profileService.profile.conditions;
    return conditions.contains(RespiratoryCondition.asthma) ||
        conditions.contains(RespiratoryCondition.chronicWheezing) ||
        conditions.contains(RespiratoryCondition.dustAllergy);
  }

  bool _isWarningCondition(double dust, double humidity) {
    final ageGroup = widget.profileService.profile.ageGroup;
    final sensitiveAge =
        ageGroup == AgeGroup.child || ageGroup == AgeGroup.senior;

    if (_hasRespiratoryCondition()) {
      return dust > 35.0 || humidity > 65.0 || humidity < 35.0;
    }

    if (sensitiveAge) {
      return dust > 35.0 || humidity > 70.0 || humidity < 30.0;
    }

    return dust > 55.0;
  }

  String _getPurityStatus(double dust, double humidity) {
    if (_isWarningCondition(dust, humidity)) {
      if (dust > 150.0) return 'Poor Air Quality';
      return 'Warning Condition';
    }
    return 'Safe Air Quality';
  }

  Color _getPurityColor(double dust, double humidity) {
    if (_isWarningCondition(dust, humidity)) {
      if (dust > 150.0) return AppColors.dangerRed;
      return AppColors.moderateYellow;
    }
    return AppColors.primaryGreen;
  }

  IconData _getPurityIcon(double dust, double humidity) {
    if (_isWarningCondition(dust, humidity)) {
      if (dust > 150.0) return Icons.dangerous_outlined;
      return Icons.warning_amber_rounded;
    }
    return Icons.shield_outlined;
  }

  String _getAqiLevel(double dust, double humidity) {
    if (_isWarningCondition(dust, humidity)) {
      return dust > 150.0 ? 'Unhealthy' : 'Moderate';
    }
    return dust <= 12.0 ? 'Excellent' : 'Good';
  }

  String _getHealthTip(double dust, double humidity) {
    if (_hasRespiratoryCondition()) {
      if (humidity > 65.0) {
        return 'High humidity! Mold risk increased. Use a dehumidifier.';
      }
      if (humidity < 35.0) {
        return 'Air is too dry. May irritate airways. Use a humidifier.';
      }
      if (dust > 35.0) {
        return 'Dust levels rising. Keep inhaler nearby and limit exertion.';
      }
    }

    final ageGroup = widget.profileService.profile.ageGroup;
    if ((ageGroup == AgeGroup.child || ageGroup == AgeGroup.senior) &&
        dust > 35.0) {
      return 'Sensitive age group detected. Reduce exposure until conditions improve.';
    }

    if (dust > 150.0) {
      return 'Limit outdoor activity. Close windows and use air purifiers.';
    }
    if (dust > 55.0) {
      return 'Sensitive individuals should reduce prolonged outdoor exertion.';
    }
    return 'Great conditions for outdoor activities. Enjoy your day!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StreamBuilder<bool>(
          stream: widget.bleService.connectionStateStream,
          initialData: widget.bleService.isConnected,
          builder: (context, connectionSnapshot) {
            final isConnected = connectionSnapshot.data ?? false;

            if (!isConnected) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for Background Connection',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ensure BreatheSafe is powered on.',
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (_latestData == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for sensor data...',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                children: [
                  // ── Header ──
                  _buildHeader(),

                  const SizedBox(height: 24),

                  // ── Air Purity Ring ──
                  AirPurityRing(dustDensity: _latestData!.dustDensity),

                  const SizedBox(height: 24),

                  // ── Status Badge ──
                  _buildStatusBadge(),

                  const SizedBox(height: 32),

                  // ── Scan Button ──
                  ScanButton(onPressed: _handleScan, isScanning: _isScanning),
                  const SizedBox(height: 12),
                  Text(
                    _isScanning ? 'Syncing...' : 'Connected in Background',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── AQI Breakdown ──
                  _buildSectionTitle(
                    'Air Composition',
                    Icons.bubble_chart_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildAqiBreakdown(),

                  const SizedBox(height: 28),

                  // ── Trend Chart ──
                  _buildSectionTitle('Dust Trend', Icons.show_chart_rounded),
                  const SizedBox(height: 12),
                  _buildTrendCard(),

                  const SizedBox(height: 28),

                  // ── Climate Readings ──
                  _buildSectionTitle(
                    'Climate Readings',
                    Icons.thermostat_auto_outlined,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: MiniTelemetryRing(
                            value: _latestData!.humidity,
                            maxValue: 100,
                            label: 'Humidity',
                            unit: '%',
                            color: AppColors.humidityBlue,
                            icon: Icons.water_drop_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MiniTelemetryRing(
                            value: _latestData!.temperature,
                            maxValue: 50,
                            label: 'Temperature',
                            unit: '°C',
                            color: AppColors.temperatureOrange,
                            icon: Icons.thermostat_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_latestData!.dhtValid) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTelemetryNote(
                        'DHT read failed. Climate values are the last valid reading.',
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Health Tips ──
                  _buildHealthTipCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────── HEADER ───────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerGlow,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(
                  alpha: 0.05 * _headerGlow.value,
                ),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              // App icon with glow
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGreen, AppColors.accentGreen],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/appicon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.spa, color: Colors.white, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BreatheSafe',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGreen.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live BLE Link',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // AQI Level badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getPurityColor(
                    _latestData!.dustDensity,
                    _latestData!.humidity,
                  ).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getPurityColor(
                      _latestData!.dustDensity,
                      _latestData!.humidity,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _getAqiLevel(_latestData!.dustDensity, _latestData!.humidity),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _getPurityColor(
                      _latestData!.dustDensity,
                      _latestData!.humidity,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────── STATUS BADGE ───────────
  Widget _buildStatusBadge() {
    final dust = _latestData!.dustDensity;
    final hum = _latestData!.humidity;
    final color = _getPurityColor(dust, hum);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getPurityIcon(dust, hum), color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _getPurityStatus(dust, hum),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── SECTION TITLE ───────────
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGreen),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            width: 50,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withValues(alpha: 0.5),
                  AppColors.primaryGreen.withValues(alpha: 0.0),
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── AQI BREAKDOWN ───────────
  Widget _buildAqiBreakdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAqiMetric(
                  'PM2.5',
                  _latestData!.pm25.toStringAsFixed(1),
                  'μg/m³',
                  _latestData!.pm25 < 35
                      ? AppColors.primaryGreen
                      : AppColors.dangerRed,
                  Icons.grain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAqiMetric(
                  'CO₂',
                  _latestData!.co2.toStringAsFixed(0),
                  'ppm',
                  _latestData!.co2 < 1000
                      ? AppColors.primaryGreen
                      : AppColors.moderateYellow,
                  Icons.cloud_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAqiMetric(
                  'VOC',
                  _latestData!.voc.toStringAsFixed(2),
                  'mg/m³',
                  _latestData!.voc < 1
                      ? AppColors.primaryGreen
                      : AppColors.dangerRed,
                  Icons.science_outlined,
                ),
              ),
            ],
          ),
          if (_latestData!.hasEstimatedComposition) ...[
            const SizedBox(height: 10),
            _buildTelemetryNote(
              'Composition values are estimated from optical dust density.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTelemetryNote(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.moderateYellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.moderateYellow.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildAqiMetric(
    String label,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── TREND CARD ───────────
  Widget _buildTrendCard() {
    final history = widget.bleService.dustHistory;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dust Density (μg/m³)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'BLE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentGreen,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          history.length >= 2
              ? SparklineChart(data: history)
              : SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      'Collecting data...',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTrendStat(
                'Current',
                _latestData!.dustDensity.toStringAsFixed(1),
                _getPurityColor(_latestData!.dustDensity, _latestData!.humidity),
              ),
              _buildTrendStat(
                'Peak',
                history.isNotEmpty
                    ? history.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)
                    : '--',
                AppColors.dangerRed, // Peak dust is bad
              ),
              _buildTrendStat(
                'Low',
                history.isNotEmpty
                    ? history.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)
                    : '--',
                AppColors.primaryGreen, // Low dust is good
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  // ─────────── HEALTH TIP ───────────
  Widget _buildHealthTipCard() {
    final dust = _latestData!.dustDensity;
    final hum = _latestData!.humidity;
    final color = _getPurityColor(dust, hum);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.08), AppColors.cardSurface],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.health_and_safety_outlined,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Advisory',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getHealthTip(dust, hum),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
