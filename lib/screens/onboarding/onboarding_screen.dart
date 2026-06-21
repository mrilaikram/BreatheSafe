import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../services/background_alert_service.dart';
import '../../services/profile_service.dart';
import '../../utils/constants.dart';
import 'age_group_step.dart';
import 'conditions_step.dart';

class OnboardingScreen extends StatefulWidget {
  final ProfileService profileService;

  const OnboardingScreen({super.key, required this.profileService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  AgeGroup? _selectedAge;
  final Set<RespiratoryCondition> _selectedConditions = {};

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final profile = UserProfile(
      ageGroup: _selectedAge,
      conditions: _selectedConditions,
    );
    await widget.profileService.updateProfile(profile);
    await BackgroundAlertService.configureFromProfile(widget.profileService);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == 1;
    final canProceed =
        (_currentPage == 0 && _selectedAge != null) ||
        (_currentPage == 1 && _selectedConditions.isNotEmpty);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgWhite, AppColors.bgGray],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Row(
                  children: [
                    _StepIndicator(
                      isActive: _currentPage >= 0,
                      isCompleted: _currentPage > 0,
                    ),
                    const SizedBox(width: 12),
                    _StepIndicator(
                      isActive: _currentPage >= 1,
                      isCompleted: false,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    AgeGroupStep(
                      selectedAge: _selectedAge,
                      onSelected: (age) {
                        setState(() => _selectedAge = age);
                        Future.delayed(
                          const Duration(milliseconds: 400),
                          _nextPage,
                        );
                      },
                    ),
                    ConditionsStep(
                      selectedConditions: _selectedConditions,
                      onToggle: (condition) {
                        setState(() {
                          if (condition == RespiratoryCondition.none) {
                            _selectedConditions.clear();
                            _selectedConditions.add(condition);
                          } else {
                            _selectedConditions.remove(
                              RespiratoryCondition.none,
                            );
                            if (_selectedConditions.contains(condition)) {
                              _selectedConditions.remove(condition);
                            } else {
                              _selectedConditions.add(condition);
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: canProceed ? 1.0 : 0.5,
                  child: ElevatedButton(
                    onPressed: canProceed ? _nextPage : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: Text(isLastPage ? 'Complete Profile' : 'Continue'),
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

class _StepIndicator extends StatelessWidget {
  final bool isActive;
  final bool isCompleted;

  const _StepIndicator({required this.isActive, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 6,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryGreen : AppColors.divider,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
