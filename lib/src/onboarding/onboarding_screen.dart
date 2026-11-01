import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_screen.dart';
import '../notifications/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _customGoalController = TextEditingController();
  int _currentPage = 0;

  String _selectedGoal = '2000';
  String _unit = 'mL';
  bool _remindersEnabled = true;
  bool _notificationPermissionInProgress = false;
  bool _notificationPermissionGranted = false;
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 0);
  double _reminderInterval = 2;

  static const Color _skyBlue = Color(0xFF12BFE6);
  static const Color _skyBlueDark = Color(0xFF087FEA);
  static const Color _ink = Color(0xFF123B63);
  static const Color _muted = Color(0xFF527796);
  static const Color _card = Color(0xFFFFFFFF);

  @override
  void dispose() {
    _pageController.dispose();
    _customGoalController.dispose();
    super.dispose();
  }

  Future<bool> _requestNotificationPermission() async {
    if (_notificationPermissionInProgress) return false;
    setState(() => _notificationPermissionInProgress = true);
    final granted = await NotificationService.instance.requestPermission();
    if (!mounted) return granted;
    setState(() {
      _notificationPermissionInProgress = false;
      _notificationPermissionGranted = granted;
      if (!granted) _remindersEnabled = false;
    });
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are off. You can enable them later in device settings.',
          ),
        ),
      );
    }
    return granted;
  }

  Future<void> _goToNextPage() async {
    if (_notificationPermissionInProgress) return;
    if (_currentPage == 1 && _selectedGoal == 'Custom') {
      final customGoal = int.tryParse(_customGoalController.text.trim());
      if (customGoal == null || customGoal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a custom daily water goal.')),
        );
        return;
      }
    }

    if (_currentPage < 3) {
      if (_currentPage == 2 &&
          _remindersEnabled &&
          !_notificationPermissionGranted) {
        await _requestNotificationPermission();
      }
      final nextPage = _currentPage + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage = nextPage);
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('onboarding_completed', true);
    await preferences.setInt(
      'daily_goal',
      _selectedGoal == 'Custom'
          ? int.parse(_customGoalController.text.trim())
          : int.parse(_selectedGoal),
    );
    await preferences.setString('water_unit', _unit);
    await preferences.setBool('reminders_enabled', _remindersEnabled);
    await preferences.setString(
      'reminder_start',
      '${_wakeTime.hour}:${_wakeTime.minute}',
    );
    await preferences.setString(
      'reminder_end',
      '${_bedTime.hour}:${_bedTime.minute}',
    );
    await preferences.setDouble('reminder_hours', _reminderInterval);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => HomeScreen(
          dailyGoal: _selectedGoal == 'Custom'
              ? int.parse(_customGoalController.text.trim())
              : int.parse(_selectedGoal),
          unit: _unit,
          remindersEnabled: _remindersEnabled,
          wakeTime: _wakeTime,
          bedTime: _bedTime,
          reminderInterval: _reminderInterval,
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }

  String _buildGoalSummary() {
    final goal = _selectedGoal == 'Custom'
        ? int.tryParse(_customGoalController.text.trim())
        : int.parse(_selectedGoal);

    if (goal == null) {
      return 'Custom goal';
    }

    if (_unit == 'mL') {
      return '$goal mL';
    }

    final ounces = (goal / 29.5735).round();
    return '$ounces oz';
  }

  String _buildReminderSummary() {
    return '${_formatTime(_wakeTime)} – ${_formatTime(_bedTime)}';
  }

  String _buildFrequencySummary() {
    if (_reminderInterval == 0.5) return 'Every 30 minutes';
    return 'Every $_reminderInterval hours';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (value) =>
                      setState(() => _currentPage = value),
                  children: [
                    _buildPage(
                      asset: 'assets/images/waving.png',
                      title: 'Meet Hydro',
                      body:
                          'A simple way to track your water and stay hydrated throughout the day.',
                      content: const SizedBox.shrink(),
                    ),
                    _buildPage(
                      asset: 'assets/images/normal.png',
                      title: 'How much water do you want to drink each day?',
                      body: '',
                      content: _buildGoalSelection(),
                    ),
                    _buildPage(
                      asset: 'assets/images/drinking.png',
                      title: 'When should Hydro remind you?',
                      body: '',
                      content: _buildReminderSelection(),
                    ),
                    _buildPage(
                      asset: 'assets/images/goal.png',
                      title: "You're all set!",
                      body:
                          'Log your drinks, keep an eye on your progress, and let Hydro remind you when it\'s time for another sip.',
                      content: _buildReadySummary(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: _currentPage == index ? 22 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _currentPage == index
                          ? _skyBlueDark
                          : const Color(0xFFBCDFF4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToNextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _skyBlueDark,
                    foregroundColor: Colors.white,
                    minimumSize: Size.fromHeight(
                      (screenHeight * 0.065).clamp(48.0, 58.0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == 0
                        ? 'Get Started'
                        : _currentPage == 1
                            ? 'Continue'
                            : _currentPage == 2
                                ? 'Continue'
                                : 'Start Hydrating',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage({
    required String asset,
    required String title,
    required String body,
    required Widget content,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final imageSize = constraints.maxWidth.clamp(210.0, 360.0);
              return SizedBox(
                width: imageSize,
                height: imageSize,
                child: Image.asset(asset, fit: BoxFit.contain),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.2,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: _muted,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 18),
          content,
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildGoalSelection() {
    final goals = ['1500', '2000', '2500', 'Custom'];

    return Column(
      children: [
        ToggleButtons(
          isSelected: [_unit == 'mL', _unit == 'oz'],
          borderRadius: BorderRadius.circular(999),
          fillColor: _skyBlue.withOpacity(0.15),
          selectedColor: _skyBlueDark,
          color: _muted,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          constraints: const BoxConstraints(minWidth: 92, minHeight: 42),
          onPressed: (index) {
            setState(() => _unit = index == 0 ? 'mL' : 'oz');
          },
          children: const [Text('mL'), Text('oz')],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: goals.map((goal) {
            final isSelected = _selectedGoal == goal;
            final label = goal == 'Custom' ? goal : '$goal $_unit';
            return ChoiceChip(
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              selected: isSelected,
              selectedColor: _skyBlue.withOpacity(0.12),
              backgroundColor: _card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected ? _skyBlueDark : const Color(0xFFE2EEF7),
                  width: 1.5,
                ),
              ),
              onSelected: (_) => setState(() => _selectedGoal = goal),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
        if (_selectedGoal == 'Custom') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _customGoalController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Custom daily goal',
              hintText: 'Enter an amount',
              suffixText: _unit,
              filled: true,
              fillColor: _card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2EEF7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2EEF7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _skyBlueDark, width: 1.5),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'You can change this anytime in Settings.',
          style: TextStyle(fontSize: 14, color: _muted),
        ),
      ],
    );
  }

  Widget _buildReminderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Enable hydration reminders',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
              ),
            ),
            Switch(
              value: _remindersEnabled,
              activeColor: _skyBlueDark,
              onChanged: (value) async {
                if (!value) {
                  setState(() => _remindersEnabled = false);
                  return;
                }
                setState(() => _remindersEnabled = true);
                await _requestNotificationPermission();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _skyBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD2EDF7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _notificationPermissionGranted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
                color: _skyBlueDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _notificationPermissionGranted
                          ? 'Notifications are enabled'
                          : 'Allow notification permission',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Hydro needs permission to remind you while the app is closed.',
                      style: TextStyle(color: _muted, height: 1.35),
                    ),
                    if (!_notificationPermissionGranted) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _notificationPermissionInProgress
                            ? null
                            : _requestNotificationPermission,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(
                          _notificationPermissionInProgress
                              ? 'Requesting permission...'
                              : 'Allow notifications',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTimeField(
            label: 'Wake time',
            value: _formatTime(_wakeTime),
            onTap: () async {
              final timePicked = await showTimePicker(
                context: context,
                initialTime: _wakeTime,
              );
              if (timePicked != null) {
                setState(() => _wakeTime = timePicked);
              }
            }),
        const SizedBox(height: 12),
        _buildTimeField(
            label: 'Bedtime',
            value: _formatTime(_bedTime),
            onTap: () async {
              final timePicked = await showTimePicker(
                context: context,
                initialTime: _bedTime,
              );
              if (timePicked != null) {
                setState(() => _bedTime = timePicked);
              }
            }),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EEF7)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Remind every',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
                ),
              ),
              DropdownButton<double>(
                value: _reminderInterval,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 0.5, child: Text('30 minutes')),
                  DropdownMenuItem(value: 1, child: Text('1 hour')),
                  DropdownMenuItem(value: 1.5, child: Text('1.5 hours')),
                  DropdownMenuItem(value: 2, child: Text('2 hours')),
                  DropdownMenuItem(value: 3, child: Text('3 hours')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _reminderInterval = value);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2EEF7)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
              ),
            ),
            Text(value,
                style: const TextStyle(fontSize: 16, color: _skyBlueDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildReadySummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EEF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryLine('Daily goal', _buildGoalSummary()),
          const SizedBox(height: 10),
          _summaryLine('Reminders', _buildReminderSummary()),
          const SizedBox(height: 10),
          _summaryLine('Frequency', _buildFrequencySummary()),
        ],
      ),
    );
  }

  Widget _summaryLine(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child:
              Text(title, style: const TextStyle(fontSize: 14, color: _muted)),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
          ),
        ),
      ],
    );
  }
}
