import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../onboarding/onboarding_screen.dart';
import '../notifications/notification_service.dart';

class WaterEntry {
  const WaterEntry({
    required this.id,
    required this.amountMl,
    required this.timestamp,
    required this.source,
  });

  final String id;
  final int amountMl;
  final DateTime timestamp;
  final String source;

  Map<String, Object> toJson() => {
        'id': id,
        'amountMl': amountMl,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
        id: json['id'] as String,
        amountMl: json['amountMl'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
        source: json['source'] as String,
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dailyGoal,
    required this.unit,
    required this.remindersEnabled,
    required this.wakeTime,
    required this.bedTime,
    required this.reminderInterval,
  });

  final int dailyGoal;
  final String unit;
  final bool remindersEnabled;
  final TimeOfDay wakeTime;
  final TimeOfDay bedTime;
  final double reminderInterval;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _blue = Color(0xFF0F7BE6);
  static const Color _ink = Color(0xFF1C3B5D);
  static const Color _muted = Color(0xFF5A7897);
  static const Color _background = Color(0xFFF4FBFF);

  static const String _entriesKey = 'water_entries';
  static const String _goalKey = 'daily_goal';
  static const String _unitKey = 'water_unit';
  static const String _defaultDrinkKey = 'default_drink';
  static const String _remindersEnabledKey = 'reminders_enabled';
  static const String _reminderStartKey = 'reminder_start';
  static const String _reminderEndKey = 'reminder_end';
  static const String _reminderHoursKey = 'reminder_hours';
  static const String _stopAfterGoalKey = 'stop_after_goal';
  static const String _soundKey = 'reminder_sound';
  static const String _vibrationKey = 'reminder_vibration';
  static const String _themeKey = 'theme_mode';
  static const String _mascotAnimationsKey = 'mascot_animations';
  static const String _reduceAnimationsKey = 'reduce_animations';
  static const String _confirmLargeEntriesKey = 'confirm_large_entries';
  static const String _loggingFeedbackKey = 'logging_feedback';
  List<WaterEntry> _entries = [];
  int _selectedTab = 0;
  bool _isLoading = true;
  bool _entriesLoaded = false;
  bool _preferencesLoaded = false;
  bool _notificationSyncInProgress = false;
  bool _notificationSyncQueued = false;
  String _historyMode = 'Week';
  int _historyOffset = 0;
  late bool _remindersEnabled = widget.remindersEnabled;
  late TimeOfDay _reminderStart = widget.wakeTime;
  late TimeOfDay _reminderEnd = widget.bedTime;
  late double _reminderHours = widget.reminderInterval;
  bool _stopAfterGoal = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  late int _dailyGoal = widget.dailyGoal;
  late String _unit = widget.unit;
  int _defaultDrink = 250;
  bool _mascotAnimations = true;
  bool _reduceAnimations = false;
  bool _confirmLargeEntries = true;
  bool _loggingFeedback = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isCustomAmountEditorOpen = false;
  final TextEditingController _customAmountController = TextEditingController();

  double get _progress => (_consumed / _dailyGoal).clamp(0, 1).toDouble();
  int get _consumed => _entries
      .where((entry) => _isSameDate(entry.timestamp, DateTime.now()))
      .fold(0, (total, entry) => total + entry.amountMl);
  int get _remaining => (_dailyGoal - _consumed).clamp(0, _dailyGoal);
  int get _percentage => (_consumed / _dailyGoal * 100).round();
  int get _extraIntake => (_consumed - _dailyGoal).clamp(0, _consumed);
  Duration get _uiAnimationDuration =>
      _reduceAnimations ? Duration.zero : const Duration(milliseconds: 220);
  Duration get _mascotAnimationDuration =>
      _mascotAnimations ? _uiAnimationDuration : Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _loadPreferences();
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  bool _isSameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  Future<void> _loadEntries() async {
    final preferences = await SharedPreferences.getInstance();
    final savedEntries = preferences.getStringList(_entriesKey) ?? [];
    final entries = <WaterEntry>[];
    for (final encodedEntry in savedEntries) {
      try {
        entries.add(
          WaterEntry.fromJson(
            jsonDecode(encodedEntry) as Map<String, dynamic>,
          ),
        );
      } on FormatException {
        // Ignore malformed legacy data and keep valid entries.
      } on TypeError {
        // Ignore malformed legacy data and keep valid entries.
      }
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
      _entriesLoaded = true;
    });
    await _maybeSyncNotifications();
  }

  Future<void> _saveEntries() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _entriesKey,
      _entries.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dailyGoal = preferences.getInt(_goalKey) ?? widget.dailyGoal;
      _unit = preferences.getString(_unitKey) ?? widget.unit;
      _defaultDrink = preferences.getInt(_defaultDrinkKey) ?? 250;
      _remindersEnabled =
          preferences.getBool(_remindersEnabledKey) ?? _remindersEnabled;
      _reminderStart =
          _readTime(preferences.getString(_reminderStartKey), _reminderStart);
      _reminderEnd =
          _readTime(preferences.getString(_reminderEndKey), _reminderEnd);
      _reminderHours =
          preferences.getDouble(_reminderHoursKey) ?? _reminderHours;
      _stopAfterGoal = preferences.getBool(_stopAfterGoalKey) ?? _stopAfterGoal;
      _soundEnabled = preferences.getBool(_soundKey) ?? _soundEnabled;
      _vibrationEnabled =
          preferences.getBool(_vibrationKey) ?? _vibrationEnabled;
      _themeMode = _readTheme(preferences.getString(_themeKey));
      _mascotAnimations =
          preferences.getBool(_mascotAnimationsKey) ?? _mascotAnimations;
      _reduceAnimations =
          preferences.getBool(_reduceAnimationsKey) ?? _reduceAnimations;
      _confirmLargeEntries =
          preferences.getBool(_confirmLargeEntriesKey) ?? _confirmLargeEntries;
      _loggingFeedback =
          preferences.getBool(_loggingFeedbackKey) ?? _loggingFeedback;
      _preferencesLoaded = true;
    });
    await _maybeSyncNotifications();
  }

  Future<void> _maybeSyncNotifications() async {
    if (!_entriesLoaded || !_preferencesLoaded) return;
    await _syncNotifications();
  }

  Future<void> _syncNotifications({bool requestPermission = false}) async {
    if (_notificationSyncInProgress) {
      _notificationSyncQueued = true;
      return;
    }
    _notificationSyncInProgress = true;
    try {
      if (requestPermission && _remindersEnabled) {
        final granted = await NotificationService.instance.requestPermission();
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Notification permission is disabled in system settings.'),
            ),
          );
        }
      }

      await NotificationService.instance.scheduleReminders(
        enabled: _remindersEnabled,
        now: DateTime.now(),
        startHour: _reminderStart.hour,
        startMinute: _reminderStart.minute,
        endHour: _reminderEnd.hour,
        endMinute: _reminderEnd.minute,
        intervalHours: _reminderHours,
        stopAfterGoal: _stopAfterGoal,
        goalReachedToday: _progress >= 1,
        sound: _soundEnabled,
        vibration: _vibrationEnabled,
      );
    } finally {
      _notificationSyncInProgress = false;
      if (_notificationSyncQueued) {
        _notificationSyncQueued = false;
        await _maybeSyncNotifications();
      }
    }
  }

  Future<void> _savePreference(String key, Object value) async {
    final preferences = await SharedPreferences.getInstance();
    if (value is int) await preferences.setInt(key, value);
    if (value is String) await preferences.setString(key, value);
    if (value is bool) await preferences.setBool(key, value);
    if (value is double) await preferences.setDouble(key, value);
  }

  TimeOfDay _readTime(String? value, TimeOfDay fallback) {
    if (value == null) return fallback;
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  ThemeMode _readTheme(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  String _timeValue(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _displayAmount(int milliliters) {
    if (_unit == 'mL') {
      return '$milliliters mL';
    }
    return '${(milliliters / 29.5735).round()} oz';
  }

  String _greeting() {
    final hour = TimeOfDay.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 18) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  String _today() {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  String _message() {
    if (_progress >= 1) {
      return 'Goal reached — nice job staying hydrated.';
    }
    if (_remaining <= _dailyGoal ~/ 4) {
      return 'Just ${_displayAmount(_remaining)} to go.';
    }
    if (_progress >= 0.5) return "You're halfway there.";
    return "Let's get hydrated.";
  }

  String _mascotAsset() {
    final hour = TimeOfDay.now().hour;
    if (hour >= 21 && _progress < 0.5) return 'assets/images/sleepy.png';
    if (_progress >= 1) return 'assets/images/goal.png';
    if (_progress >= 0.75) return 'assets/images/waving.png';
    if (_progress > 0.25) return 'assets/images/normal.png';
    return 'assets/images/thirsty.png';
  }

  Future<void> _addWater(int amount, {String source = 'quick_add'}) async {
    if (amount <= 0) return;
    if (amount > 1500 && _confirmLargeEntries) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Large amount'),
          content: Text(
            '${_displayAmount(amount)} is a large single entry. '
            'Are you sure you want to log it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log amount'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final wasGoalReached = _progress >= 1;
    final entry = WaterEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amountMl: amount,
      timestamp: DateTime.now(),
      source: source,
    );
    setState(() => _entries = [..._entries, entry]);
    await _saveEntries();
    if (wasGoalReached != (_progress >= 1)) {
      await _syncNotifications();
    }
    if (!mounted) return;
    if (_loggingFeedback) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_displayAmount(amount)} added'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                _entries = _entries
                    .where((savedEntry) => savedEntry.id != entry.id)
                    .toList();
              });
              await _saveEntries();
            },
          ),
        ),
      );
    }
  }

  void _openCustomAmountEditor() {
    setState(() {
      _isCustomAmountEditorOpen = true;
      _customAmountController.clear();
    });
  }

  void _cancelCustomAmount() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isCustomAmountEditorOpen = false;
      _customAmountController.clear();
    });
  }

  Future<void> _submitCustomAmount() async {
    final value = int.tryParse(_customAmountController.text.trim());
    if (value == null || value <= 0) return;
    final amount = _unit == 'mL' ? value : (value * 29.5735).round();
    _cancelCustomAmount();
    await _addWater(amount, source: 'custom');
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _themeMode == ThemeMode.dark
        ? Brightness.dark
        : _themeMode == ThemeMode.light
            ? Brightness.light
            : MediaQuery.platformBrightnessOf(context);
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _blue,
          brightness: brightness,
        ).copyWith(
          primary: _blue,
          secondary: const Color(0xFF12BFE6),
          surface: brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF10283D),
        ),
        brightness: brightness,
        scaffoldBackgroundColor: brightness == Brightness.light
            ? const Color(0xFFF0FAFF)
            : const Color(0xFF091C2D),
      ),
      child: Scaffold(
        backgroundColor: _background,
        appBar: _selectedTab == 0
            ? null
            : AppBar(
                backgroundColor: _background,
                elevation: 0,
                title: Text(
                  _sectionTitle,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedTab == 0
                ? _buildHome()
                : _selectedTab == 1
                    ? _buildHistory()
                    : _selectedTab == 2
                        ? _buildReminderSettings()
                        : _buildSettings(),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  String get _sectionTitle {
    switch (_selectedTab) {
      case 1:
        return 'Insights';
      case 2:
        return 'Reminders';
      case 3:
        return 'Settings';
      default:
        return 'Today';
    }
  }

  Widget _buildBottomNavigationBar() {
    const destinations = [
      (Icons.water_drop_outlined, Icons.water_drop, 'Today'),
      (Icons.insights_outlined, Icons.insights, 'Insights'),
      (Icons.notifications_none, Icons.notifications, 'Reminders'),
      (Icons.tune_outlined, Icons.tune, 'Settings'),
    ];

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFDCEFF8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x180F7BE6),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(destinations.length, (index) {
            final destination = destinations[index];
            final isSelected = _selectedTab == index;
            return Expanded(
              child: Semantics(
                button: true,
                selected: isSelected,
                label: destination.$3,
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = index),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: _uiAnimationDuration,
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE6F7FF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: _uiAnimationDuration,
                          child: Icon(
                            isSelected ? destination.$2 : destination.$1,
                            key: ValueKey(isSelected),
                            color: isSelected ? _blue : _muted,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          destination.$3,
                          style: TextStyle(
                            color: isSelected ? _blue : _muted,
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHome() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen =
            constraints.maxHeight < 700 || constraints.maxWidth < 340;
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _today(),
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AnimatedContainer(
              duration: _uiAnimationDuration,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _progress >= 1
                      ? const [Color(0xFFE9FAF3), Color(0xFFF7FCFF)]
                      : const [Color(0xFFE5F6FF), Color(0xFFF8FCFF)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _progress >= 1
                      ? const Color(0xFFC9EEDC)
                      : const Color(0xFFD4ECF8),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F7BE6),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isVeryNarrow = constraints.maxWidth < 300;
                  final columnWidth = (constraints.maxWidth - 8) / 2;
                  final ringSize =
                      (columnWidth - 8).clamp(0.0, 210.0).toDouble();
                  final mascotSize =
                      (columnWidth - 8).clamp(0.0, 170.0).toDouble();
                  final progress = _buildProgressRing(ringSize);

                  if (isVeryNarrow) {
                    return Column(
                      children: [
                        AnimatedSwitcher(
                          duration: _mascotAnimationDuration,
                          child: Image.asset(
                            _mascotAsset(),
                            key: ValueKey(_mascotAsset()),
                            height: mascotSize,
                          ),
                        ),
                        const SizedBox(height: 8),
                        progress,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: _mascotAnimationDuration,
                            child: Image.asset(
                              _mascotAsset(),
                              key: ValueKey(_mascotAsset()),
                              width: mascotSize,
                              height: mascotSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Center(child: progress)),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _message(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              _progress >= 1
                  ? _extraIntake > 0
                      ? 'Goal completed · ${_displayAmount(_extraIntake)} above target'
                      : 'Daily goal completed'
                  : '${_displayAmount(_remaining)} remaining',
              style:
                  const TextStyle(color: _muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 22),
            _buildQuickAdd(),
            const SizedBox(height: 16),
            _buildSummary(),
            const SizedBox(height: 12),
            _buildReminder(),
            if (_consumed >= _dailyGoal) ...[
              const SizedBox(height: 12),
              _buildStreak(),
            ],
          ],
        );

        if (isSmallScreen) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            child: content,
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: content,
        );
      },
    );
  }

  Widget _buildProgressRing(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 18,
              backgroundColor: const Color(0xFFD8EFFB),
              color: _blue,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _displayAmount(_consumed),
                style: const TextStyle(
                    color: _ink, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Text('of ${_displayAmount(_dailyGoal)}',
                  style: const TextStyle(color: _muted)),
              const SizedBox(height: 4),
              Text('$_percentage%',
                  style: const TextStyle(
                      color: _blue, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAdd() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick add',
            style: TextStyle(
                color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (_isCustomAmountEditorOpen) _buildCustomAmountEditor(),
        if (!_isCustomAmountEditorOpen)
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 24) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quickAddButton(150, width: itemWidth),
                  _quickAddButton(_defaultDrink,
                      primary: true, width: itemWidth),
                  _quickAddButton(500, width: itemWidth),
                  SizedBox(
                    width: itemWidth,
                    child: OutlinedButton(
                      onPressed: _openCustomAmountEditor,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('+ Custom'),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildCustomAmountEditor() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE9F9FF), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add water',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: _cancelCustomAmount,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              'Enter the amount you drank',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _customAmountController,
              autofocus: true,
              onSubmitted: (_) => _submitCustomAmount(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: _unit,
                hintText: 'Enter amount',
                prefixIcon: const Icon(Icons.water_drop_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitCustomAmount,
                child: const Text('Add drink'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAddButton(int amount,
      {bool primary = false, required double width}) {
    return SizedBox(
      width: width,
      child: primary
          ? FilledButton(
              onPressed: () => _addWater(amount),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('+${_displayAmount(amount)}'),
            )
          : OutlinedButton(
              onPressed: () => _addWater(amount),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('+${_displayAmount(amount)}'),
            ),
    );
  }

  Widget _buildSummary() {
    return _infoCard(
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 12,
        spacing: 20,
        children: [
          _stat('${(_consumed / 250).floor()}', 'glasses'),
          _stat(_displayAmount(_consumed), 'consumed'),
          _stat(_displayAmount(_remaining), 'remaining'),
        ],
      ),
    );
  }

  Widget _buildReminder() {
    return _infoCard(
      child: Row(
        children: [
          Icon(
            _progress >= 1
                ? Icons.check_circle_outline
                : Icons.notifications_none,
            color: _progress >= 1 ? Colors.green : _blue,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _progress >= 1
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily goal reached',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                      Text(
                        'Routine reminders paused for today',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : _remindersEnabled
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Next reminder',
                              style: TextStyle(color: _muted, fontSize: 13)),
                          Text(
                            '${_intervalLabel()} from now',
                            style: const TextStyle(
                                color: _ink, fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    : const Text('Reminders are off',
                        style: TextStyle(
                            color: _ink, fontWeight: FontWeight.w700)),
          ),
          if (!_remindersEnabled)
            TextButton(onPressed: () {}, child: const Text('Enable')),
        ],
      ),
    );
  }

  Widget _buildStreak() {
    return _infoCard(
      child: Row(
        children: [
          Text('🔥', style: TextStyle(fontSize: 24)),
          SizedBox(width: 12),
          Text('1 day streak',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
          Spacer(),
          Text('Keep it going.', style: TextStyle(color: _muted)),
        ],
      ),
    );
  }

  Widget _buildReminderSettings() {
    final enabledColor = _remindersEnabled ? _ink : _muted.withOpacity(0.55);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        const Text(
          'Gentle reminders during your active hours.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 20),
        _infoCard(
          child: Column(
            children: [
              _settingsSwitch(
                title: 'Enable reminders',
                subtitle: _remindersEnabled
                    ? 'Hydro will remind you to take a sip.'
                    : 'Reminders are currently paused.',
                value: _remindersEnabled,
                onChanged: (value) async {
                  setState(() => _remindersEnabled = value);
                  await _savePreference(_remindersEnabledKey, value);
                  await _syncNotifications(requestPermission: value);
                },
              ),
              const Divider(height: 24),
              _settingsTimeRow(
                label: 'Start time',
                value: _formatReminderTime(_reminderStart),
                enabled: _remindersEnabled,
                onTap: () => _pickReminderTime(true),
              ),
              const SizedBox(height: 14),
              _settingsTimeRow(
                label: 'End time',
                value: _formatReminderTime(_reminderEnd),
                enabled: _remindersEnabled,
                onTap: () => _pickReminderTime(false),
              ),
              const SizedBox(height: 14),
              _settingsDropdown(),
              const Divider(height: 28),
              _settingsSwitch(
                title: 'Stop after daily goal',
                subtitle:
                    'Pause remaining reminders after you reach your goal.',
                value: _stopAfterGoal,
                enabled: _remindersEnabled,
                onChanged: (value) async {
                  setState(() => _stopAfterGoal = value);
                  await _savePreference(_stopAfterGoalKey, value);
                  await _syncNotifications();
                },
              ),
              const Divider(height: 24),
              _settingsSwitch(
                title: 'Sound',
                subtitle: 'Play a sound with each reminder.',
                value: _soundEnabled,
                enabled: _remindersEnabled,
                onChanged: (value) async {
                  setState(() => _soundEnabled = value);
                  await _savePreference(_soundKey, value);
                  await _syncNotifications();
                },
              ),
              const SizedBox(height: 12),
              _settingsSwitch(
                title: 'Vibration',
                subtitle: 'Vibrate gently with each reminder.',
                value: _vibrationEnabled,
                enabled: _remindersEnabled,
                onChanged: (value) async {
                  setState(() => _vibrationEnabled = value);
                  await _savePreference(_vibrationKey, value);
                  await _syncNotifications();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _infoCard(
          child: Row(
            children: [
              Icon(
                _remindersEnabled
                    ? Icons.schedule_outlined
                    : Icons.notifications_off_outlined,
                color: _remindersEnabled ? _blue : _muted,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _remindersEnabled
                      ? _stopAfterGoal && _progress >= 1
                          ? 'Reminders paused for today because you reached your goal.'
                          : 'Schedule: ${_formatReminderTime(_reminderStart)} – ${_formatReminderTime(_reminderEnd)} every ${_intervalLabel()}'
                      : 'Reminders are off. Enable them whenever you are ready.',
                  style: TextStyle(
                    color: enabledColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _infoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: _muted),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Notifications may require permission from your device settings. '
                  'Hydro will never schedule reminders outside your active hours.',
                  style: TextStyle(color: _muted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _remindersEnabled
              ? () async {
                  await NotificationService.instance.scheduleSnooze(
                    sound: _soundEnabled,
                    vibration: _vibrationEnabled,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Next reminder snoozed for 30 minutes.'),
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.snooze_outlined),
          label: const Text('Snooze next reminder · 30 min'),
        ),
      ],
    );
  }

  Widget _settingsSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final color = enabled ? _ink : _muted.withOpacity(0.55);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(
                      color: enabled ? _muted : _muted.withOpacity(0.55),
                      fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: _blue,
        ),
      ],
    );
  }

  Widget _settingsTimeRow({
    required String label,
    required String value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: enabled ? _ink : _muted.withOpacity(0.55),
                    fontWeight: FontWeight.w700)),
          ),
          Text(value,
              style: TextStyle(
                  color: enabled ? _blue : _muted.withOpacity(0.55),
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right,
              color: enabled ? _muted : _muted.withOpacity(0.55)),
        ],
      ),
    );
  }

  Widget _settingsDropdown() {
    final intervalValue =
        _isPresetInterval(_reminderHours) ? _intervalLabel() : 'Custom';
    return Row(
      children: [
        Expanded(
          child: Text(
            'Remind me every',
            style: TextStyle(
              color: _remindersEnabled ? _ink : _muted.withOpacity(0.55),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DropdownButton<String>(
          value: intervalValue,
          underline: const SizedBox(),
          disabledHint: Text(_intervalLabel()),
          items: const [
            DropdownMenuItem(value: '0.5 hours', child: Text('30 minutes')),
            DropdownMenuItem(value: '1 hour', child: Text('1 hour')),
            DropdownMenuItem(value: '1.5 hours', child: Text('1.5 hours')),
            DropdownMenuItem(value: '2 hours', child: Text('2 hours')),
            DropdownMenuItem(value: '3 hours', child: Text('3 hours')),
            DropdownMenuItem(value: 'Custom', child: Text('Custom')),
          ],
          onChanged: _remindersEnabled
              ? (value) async {
                  if (value == null) return;
                  if (value == 'Custom') {
                    await _chooseCustomInterval();
                    return;
                  }
                  final interval = {
                    '0.5 hours': 0.5,
                    '1 hour': 1.0,
                    '1.5 hours': 1.5,
                    '2 hours': 2.0,
                    '3 hours': 3.0,
                  }[value];
                  if (interval != null) {
                    setState(() => _reminderHours = interval);
                    await _savePreference(_reminderHoursKey, interval);
                    await _syncNotifications();
                  }
                }
              : null,
        ),
      ],
    );
  }

  String _intervalLabel() {
    if (_reminderHours == 0.5) return '30 minutes';
    if (_reminderHours == _reminderHours.round()) {
      return '${_reminderHours.round()} hours';
    }
    return '$_reminderHours hours';
  }

  bool _isPresetInterval(double interval) =>
      interval == 0.5 ||
      interval == 1 ||
      interval == 1.5 ||
      interval == 2 ||
      interval == 3;

  Future<void> _chooseCustomInterval() async {
    final controller = TextEditingController(
      text: (_reminderHours * 60).round().toString(),
    );
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom reminder interval'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'For example, 90',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 30) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (minutes != null && mounted) {
      setState(() => _reminderHours = minutes / 60);
      await _savePreference(_reminderHoursKey, minutes / 60);
      await _syncNotifications();
    }
  }

  String _formatReminderTime(TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  Future<void> _pickReminderTime(bool isStart) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _reminderStart : _reminderEnd,
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        _reminderStart = selected;
      } else {
        _reminderEnd = selected;
      }
    });
    await _savePreference(
      isStart ? _reminderStartKey : _reminderEndKey,
      _timeValue(selected),
    );
    await _syncNotifications();
  }

  Widget _buildHistory() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      children: [
        const Text(
          'See your progress and keep your hydration consistent.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 20),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Week', label: Text('Week')),
            ButtonSegment(value: 'Month', label: Text('Month')),
          ],
          selected: {_historyMode},
          onSelectionChanged: (value) => setState(() {
            _historyMode = value.first;
            _historyOffset = 0;
          }),
        ),
        const SizedBox(height: 16),
        _buildHistoryPeriodHeader(),
        const SizedBox(height: 14),
        _historyMode == 'Week' ? _buildWeekChart() : _buildMonthCalendar(),
        const SizedBox(height: 14),
        _buildHistorySummary(),
        const SizedBox(height: 20),
        const Text('Daily activity',
            style: TextStyle(
                color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...(() {
          final visibleDates = _historyDates()
              .where(
                (date) =>
                    !date.isAfter(DateTime.now()) &&
                    (_isSameDate(date, DateTime.now()) ||
                        _entriesForDate(date).isNotEmpty),
              )
              .toList()
            ..sort((first, second) => second.compareTo(first));
          return visibleDates.map(_buildDailyHistoryRow);
        })(),
      ],
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  DateTime _historyStart() {
    final today = DateTime.now();
    if (_historyMode == 'Week') {
      return _startOfWeek(today).add(Duration(days: _historyOffset * 7));
    }
    return DateTime(today.year, today.month + _historyOffset, 1);
  }

  List<DateTime> _historyDates() {
    final start = _historyStart();
    if (_historyMode == 'Week') {
      return List.generate(7, (index) => start.add(Duration(days: index)));
    }
    final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
    return List.generate(
        daysInMonth, (index) => DateTime(start.year, start.month, index + 1));
  }

  List<WaterEntry> _entriesForDate(DateTime date) =>
      _entries.where((entry) => _isSameDate(entry.timestamp, date)).toList();

  int _totalForDate(DateTime date) =>
      _entriesForDate(date).fold(0, (total, entry) => total + entry.amountMl);

  Widget _buildHistoryPeriodHeader() {
    final start = _historyStart();
    final end = _historyMode == 'Week'
        ? start.add(const Duration(days: 6))
        : DateTime(start.year, start.month + 1, 0);
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(() => _historyOffset--),
          icon: const Icon(Icons.chevron_left),
          color: _ink,
        ),
        Expanded(
          child: Text(
            _historyMode == 'Week'
                ? '${_shortDate(start)} – ${_shortDate(end)}'
                : '${_monthName(start.month)} ${start.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _ink, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: _historyOffset == 0
              ? null
              : () => setState(() => _historyOffset++),
          icon: const Icon(Icons.chevron_right),
          color: _ink,
        ),
      ],
    );
  }

  Widget _buildWeekChart() {
    final dates = _historyDates();
    final maxValue = [
      _dailyGoal,
      ...dates.map(_totalForDate),
    ].reduce((a, b) => a > b ? a : b);
    return _infoCard(
      child: SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dates.map((date) {
            final total = _totalForDate(date);
            final height = total == 0 ? 8.0 : 110 * total / maxValue;
            return Expanded(
              child: InkWell(
                onTap: () => _showDailyDetails(date),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(_chartAmount(total),
                        style: const TextStyle(color: _muted, fontSize: 10)),
                    const SizedBox(height: 5),
                    Container(
                      height: height,
                      width: 22,
                      decoration: BoxDecoration(
                        color: total >= _dailyGoal
                            ? _blue
                            : const Color(0xFF9EDCF7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_weekdayName(date.weekday),
                        style: const TextStyle(color: _muted, fontSize: 11)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthCalendar() {
    final dates = _historyDates();
    final first = dates.first.weekday - 1;
    return _infoCard(
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.85,
        children: [
          ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) => Center(
              child: Text(day,
                  style: const TextStyle(
                      color: _muted, fontWeight: FontWeight.w700)))),
          ...List.generate(first, (_) => const SizedBox()),
          ...dates.map((date) {
            final total = _totalForDate(date);
            final future = date.isAfter(DateTime.now());
            return InkWell(
              onTap: future ? null : () => _showDailyDetails(date),
              child: Column(
                children: [
                  Text('${date.day}',
                      style: const TextStyle(color: _ink, fontSize: 12)),
                  Text(
                    future
                        ? '·'
                        : total >= _dailyGoal
                            ? '●'
                            : total > 0
                                ? '◐'
                                : '○',
                    style: TextStyle(
                      color: future
                          ? _muted
                          : total >= _dailyGoal
                              ? _blue
                              : _muted,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistorySummary() {
    final dates =
        _historyDates().where((date) => !date.isAfter(DateTime.now()));
    final totals = dates.map(_totalForDate).toList();
    final reached = totals.where((total) => total >= _dailyGoal).length;
    final average = totals.isEmpty
        ? 0
        : (totals.reduce((a, b) => a + b) / totals.length).round();
    final best = totals.isEmpty ? 0 : totals.reduce((a, b) => a > b ? a : b);
    return _infoCard(
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 14,
        children: [
          _stat(_chartAmount(average), 'average/day'),
          _stat('$reached/${totals.length}', 'goals reached'),
          _stat(_chartAmount(best), 'best day'),
          _stat('${_currentStreak()} days', 'current streak'),
        ],
      ),
    );
  }

  int _currentStreak() {
    var date = DateTime.now();
    var streak = 0;
    while (_totalForDate(date) >= _dailyGoal) {
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Widget _buildDailyHistoryRow(DateTime date) {
    final total = _totalForDate(date);
    final percent = _dailyGoal == 0 ? 0 : (total / _dailyGoal * 100).round();
    final reached = total >= _dailyGoal;
    final status = reached
        ? '✓ Goal reached'
        : total == 0
            ? '○ Below goal'
            : '◐ In progress · $percent%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showDailyDetails(date),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(_historyDate(date),
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${_displayAmount(total)} / ${_displayAmount(_dailyGoal)}',
          style: const TextStyle(color: _muted),
        ),
        trailing: Text(status,
            style: TextStyle(
                color: reached ? Colors.green : _muted,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  String _shortDate(DateTime date) =>
      '${_monthName(date.month).substring(0, 3)} ${date.day}';

  String _monthName(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ][month - 1];

  String _weekdayName(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];

  String _chartAmount(int amount) =>
      amount >= 1000 ? '${(amount / 1000).toStringAsFixed(1)} L' : '$amount mL';

  Future<void> _showDailyDetails(DateTime date) async {
    final entries = _entriesForDate(date)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_historyDate(date),
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${_displayAmount(_totalForDate(date))} / ${_displayAmount(_dailyGoal)}',
                  style: const TextStyle(color: _muted),
                ),
                const Divider(height: 24),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No water logged for this day.',
                        style: TextStyle(color: _muted)),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: entries.map(_buildHistoryEntry).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  String _historyDate(DateTime date) {
    if (_isSameDate(date, DateTime.now())) return 'Today';
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (_isSameDate(date, yesterday)) return 'Yesterday';
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildHistoryEntry(WaterEntry entry) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(entry.timestamp),
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE6F7FF),
        child: Icon(Icons.water_drop, color: _blue, size: 18),
      ),
      title: Text(
        _displayAmount(entry.amountMl),
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '$time · ${entry.source == 'custom' ? 'Custom' : 'Quick add'}',
        style: const TextStyle(color: _muted),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          if (action == 'edit') _editEntry(entry);
          if (action == 'delete') _deleteEntry(entry);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  Future<void> _editEntry(WaterEntry entry) async {
    final controller = TextEditingController(
      text: _unit == 'mL'
          ? '${entry.amountMl}'
          : '${(entry.amountMl / 29.5735).round()}',
    );
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit water entry'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount',
            suffixText: _unit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(
                context,
                _unit == 'mL' ? value : (value * 29.5735).round(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0) return;
    setState(() {
      _entries = _entries
          .map(
            (savedEntry) => savedEntry.id == entry.id
                ? WaterEntry(
                    id: entry.id,
                    amountMl: amount,
                    timestamp: entry.timestamp,
                    source: entry.source,
                  )
                : savedEntry,
          )
          .toList();
    });
    await _saveEntries();
  }

  Future<void> _deleteEntry(WaterEntry entry) async {
    setState(() {
      _entries =
          _entries.where((savedEntry) => savedEntry.id != entry.id).toList();
    });
    await _saveEntries();
  }

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        const Text('Make Hydro work the way you like.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 20),
        _settingsSection('HYDRATION', [
          _settingsRow(
            'Daily goal',
            _displayAmount(_dailyGoal),
            Icons.flag_outlined,
            _editDailyGoal,
          ),
          _settingsRow(
            'Default drink',
            _displayAmount(_defaultDrink),
            Icons.local_drink_outlined,
            _editDefaultDrink,
          ),
          _settingsRow(
            'Unit',
            _unit,
            Icons.straighten_outlined,
            _chooseUnit,
          ),
        ]),
        _settingsSection('REMINDERS', [
          _settingsRow(
            'Hydration reminders',
            _remindersEnabled ? 'On' : 'Off',
            Icons.notifications_none,
            () => setState(() => _selectedTab = 2),
          ),
          _settingsRow(
            'Schedule',
            '${_formatReminderTime(_reminderStart)} – ${_formatReminderTime(_reminderEnd)}',
            Icons.schedule_outlined,
            () => setState(() => _selectedTab = 2),
          ),
          _settingsInfo(
            'Notification permissions are managed by your device settings.',
          ),
        ]),
        _settingsSection('APPEARANCE', [
          _settingsChoiceRow('Theme', _themeLabel, Icons.palette_outlined),
          _settingsToggleRow(
            'Mascot animations',
            _mascotAnimations,
            (value) async {
              setState(() => _mascotAnimations = value);
              await _savePreference(_mascotAnimationsKey, value);
            },
          ),
          _settingsToggleRow(
            'Reduce animations',
            _reduceAnimations,
            (value) async {
              setState(() => _reduceAnimations = value);
              await _savePreference(_reduceAnimationsKey, value);
            },
          ),
        ]),
        _settingsSection('LOGGING', [
          _settingsToggleRow(
            'Confirm large entries',
            _confirmLargeEntries,
            (value) async {
              setState(() => _confirmLargeEntries = value);
              await _savePreference(_confirmLargeEntriesKey, value);
            },
          ),
          _settingsToggleRow(
            'Logging feedback',
            _loggingFeedback,
            (value) async {
              setState(() => _loggingFeedback = value);
              await _savePreference(_loggingFeedbackKey, value);
            },
          ),
        ]),
        _settingsSection('DATA', [
          _settingsRow(
            'Clear hydration history',
            'Remove all entries',
            Icons.delete_outline,
            _confirmClearHistory,
          ),
          _settingsRow(
            'Reset app data',
            'Return to onboarding',
            Icons.restart_alt,
            _confirmResetData,
          ),
          _settingsInfo('Your hydration data is stored on this device.'),
        ]),
        _settingsSection('ABOUT', [
          _settingsRow(
              'About Hydro', '', Icons.water_drop_outlined, _showAbout),
          _settingsInfo('Version 1.0.0'),
        ]),
      ],
    );
  }

  Widget _settingsSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title,
                style: const TextStyle(
                    color: _blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1)),
          ),
          _infoCard(
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index < children.length - 1) const Divider(height: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow(
    String title,
    String value,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      leading: Icon(icon, color: onTap == null ? _muted : _blue),
      title: Text(title,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(value, style: const TextStyle(color: _muted)),
          if (onTap != null) const Icon(Icons.chevron_right, color: _muted),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _settingsToggleRow(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
      value: value,
      activeColor: _blue,
      onChanged: onChanged,
    );
  }

  Widget _settingsChoiceRow(String title, String value, IconData icon) {
    return _settingsRow(title, value, icon, () async {
      final selected = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['System', 'Light', 'Dark']
                .map((theme) => ListTile(
                      title: Text(theme),
                      trailing: theme == value
                          ? const Icon(Icons.check, color: _blue)
                          : null,
                      onTap: () => Navigator.pop(context, theme),
                    ))
                .toList(),
          ),
        ),
      );
      if (selected != null && mounted) {
        final mode = ThemeMode.values.firstWhere(
          (mode) => mode.name.toLowerCase() == selected.toLowerCase(),
          orElse: () => ThemeMode.system,
        );
        setState(() => _themeMode = mode);
        await _savePreference(_themeKey, mode.name);
      }
    });
  }

  String get _themeLabel {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Widget _settingsInfo(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child:
              Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
        ),
      );

  Future<void> _editDailyGoal() async {
    final controller = TextEditingController(text: '$_dailyGoal');
    final value = await _numberDialog('Daily goal', controller);
    controller.dispose();
    if (value == null || value <= 0) return;
    setState(
        () => _dailyGoal = _unit == 'mL' ? value : (value * 29.5735).round());
    await _savePreference(_goalKey, _dailyGoal);
  }

  Future<void> _editDefaultDrink() async {
    final controller = TextEditingController(text: '$_defaultDrink');
    final value = await _numberDialog('Default drink', controller);
    controller.dispose();
    if (value == null || value <= 0) return;
    setState(() =>
        _defaultDrink = _unit == 'mL' ? value : (value * 29.5735).round());
    await _savePreference(_defaultDrinkKey, _defaultDrink);
  }

  Future<int?> _numberDialog(
    String title,
    TextEditingController controller,
  ) {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: _unit),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0) Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseUnit() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['mL', 'oz']
              .map((unit) => ListTile(
                    title: Text(unit),
                    trailing: unit == _unit
                        ? const Icon(Icons.check, color: _blue)
                        : null,
                    onTap: () => Navigator.pop(context, unit),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected == null || selected == _unit) return;
    setState(() => _unit = selected);
    await _savePreference(_unitKey, _unit);
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await _confirmDestructive(
      'Clear hydration history?',
      'This will permanently remove all saved water entries and cannot be undone.',
    );
    if (!confirmed) return;
    setState(() => _entries = []);
    await _saveEntries();
  }

  Future<void> _confirmResetData() async {
    final confirmed = await _confirmDestructive(
      'Reset app data?',
      'This will remove your hydration data and return you to onboarding.',
    );
    if (!confirmed || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  Future<bool> _confirmDestructive(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Clear')),
            ],
          ),
        ) ??
        false;
  }

  void _showAbout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AboutHydroPage(
          onPrivacy: () => _openLegalPage('Privacy Policy'),
          onTerms: () => _openLegalPage('Terms of Use'),
          onLicenses: _showLicenses,
          onFeedback: _sendFeedback,
        ),
      ),
    );
  }

  void _openLegalPage(String title) {
    final isPrivacy = title == 'Privacy Policy';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LegalPage(
          title: title,
          paragraphs: isPrivacy
              ? const [
                  'Hydro respects your privacy.',
                  'The app stores your hydration data, goals, reminders, and preferences locally on your device. Hydro does not require an account and does not intentionally collect or share personal information with third parties.',
                  'If future versions of Hydro use online services, analytics, or cloud storage, this Privacy Policy may be updated accordingly.',
                ]
              : const [
                  'Hydro is designed to help users track water intake and maintain hydration habits.',
                  'The information provided by the app is for general wellness and informational purposes only and should not be considered medical advice.',
                  'Users are responsible for setting hydration goals that are appropriate for their own needs. If you have a medical condition or specific hydration requirements, consult a qualified healthcare professional.',
                  'By using Hydro, you agree to use the app at your own discretion.',
                ],
        ),
      ),
    );
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Hydro',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset('assets/images/hydro_icon.png', width: 48),
      applicationLegalese:
          'Hydro is built using Flutter and open-source packages.',
    );
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'pagatpatan.christianjoseph@gmail.com',
      queryParameters: const {
        'subject': 'Hydro Feedback (v1.0.0)',
        'body': 'Describe the issue or suggestion:',
      },
    );
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (!mounted) return;
    await Clipboard.setData(
      const ClipboardData(text: 'pagatpatan.christianjoseph@gmail.com'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No email app is available. The feedback address was copied.',
        ),
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EEF7)),
      ),
      child: child,
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }
}

class _AboutHydroPage extends StatelessWidget {
  const _AboutHydroPage({
    required this.onPrivacy,
    required this.onTerms,
    required this.onLicenses,
    required this.onFeedback,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onLicenses;
  final VoidCallback onFeedback;

  static const Color _ink = Color(0xFF1C3B5D);
  static const Color _muted = Color(0xFF5A7897);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Hydro'),
        backgroundColor: const Color(0xFFF4FBFF),
        foregroundColor: _ink,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4FBFF),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
        children: [
          Image.asset('assets/images/hydro_icon.png', width: 110, height: 110),
          const SizedBox(height: 12),
          const Text(
            'Hydro',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Stay hydrated, one sip at a time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 16),
          ),
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Text(
              'Version ${snapshot.data?.version ?? '...'}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Hydro helps you track your daily water intake, reach your hydration goals, and build healthier drinking habits.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ink, height: 1.5),
          ),
          const SizedBox(height: 18),
          const Text(
            'Hydro is for general hydration tracking and reminders only. It does not provide medical advice or determine how much water a person needs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.5, fontSize: 13),
          ),
          const SizedBox(height: 28),
          _AboutAction(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: onPrivacy,
          ),
          _AboutAction(
            icon: Icons.description_outlined,
            title: 'Terms of Use',
            onTap: onTerms,
          ),
          _AboutAction(
            icon: Icons.article_outlined,
            title: 'Open Source Licenses',
            onTap: onLicenses,
          ),
          _AboutAction(
            icon: Icons.mail_outline,
            title: 'Send Feedback',
            subtitle: 'pagatpatan.christianjoseph@gmail.com',
            onTap: onFeedback,
          ),
          const SizedBox(height: 32),
          const Text(
            'Made with Flutter',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AboutAction extends StatelessWidget {
  const _AboutAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF0F7BE6)),
      title: Text(title,
          style: const TextStyle(
              color: Color(0xFF1C3B5D), fontWeight: FontWeight.w700)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF5A7897)),
      onTap: onTap,
    );
  }
}

class _LegalPage extends StatelessWidget {
  const _LegalPage({
    required this.title,
    required this.paragraphs,
  });

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: paragraphs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (_, index) => Text(
          paragraphs[index],
          style: const TextStyle(
            color: Color(0xFF1C3B5D),
            height: 1.55,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
