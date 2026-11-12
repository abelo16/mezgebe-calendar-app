import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

final List geezNumbers = [
  "፩", "፪", "፫", "፬", "፭", "፮", "፯", "፰", "፱", "፲",
  "፲፩", "፲፪", "፲፫", "፲፬", "፲፭", "፲፮", "፲፯", "፲፰", "፲፱", "፳",
  "፳፩", "፳፪", "፳፫", "፳፬", "፳፭", "፳፮", "፳፯", "፳፰", "፳፱", "፴"
];

final List ethMonths = ["መስከረም", "ጥቅምት", "ህዳር", "ታህሳስ", "ጥር", "የካቲት", "መጋቢት", "ሚያዝያ", "ግንቦት", "ሰኔ", "ሀምሌ", "ነሀሴ", "ጳጉሜ"];
final List gcMonths = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
final List ethWeekDaysFull = ["ሰኞ", "ማክሰኞ", "ረቡዕ", "ሐሙስ", "ዓርብ", "ቅዳሜ", "እሁድ"];
final List gcWeekDaysFull = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

String toGeez(int number) => (number >= 1 && number <= 30) ? geezNumbers[number - 1].toString() : number.toString();

DateTime ethToGc(int eYear, int eMonth, int eDay) {
  int baseEYear = 2018;
  DateTime baseGcDate = DateTime(2025, 9, 11);
  int daysDifference = 0;
  if (eYear >= baseEYear) {
    for (int y = baseEYear; y < eYear; y++) {
      daysDifference += (y % 4 == 3) ? 366 : 365;
    }
  } else {
    for (int y = baseEYear - 1; y >= eYear; y--) {
      daysDifference -= (y % 4 == 3) ? 366 : 365;
    }
  }
  daysDifference += (eMonth - 1) * 30 + (eDay - 1);
  return baseGcDate.add(Duration(days: daysDifference));
}

List gcToEth(int gYear, int gMonth, int gDay) {
  DateTime targetDate = DateTime(gYear, gMonth, gDay);
  DateTime baseGcDate = DateTime(2025, 9, 11);
  int daysDiff = targetDate.difference(baseGcDate).inDays;
  int eYear = 2018;
  if (daysDiff >= 0) {
    while (true) {
      int daysInYear = (eYear % 4 == 3) ? 366 : 365;
      if (daysDiff < daysInYear) break;
      daysDiff -= daysInYear;
      eYear++;
    }
  } else {
    while (daysDiff < 0) {
      eYear--;
      int daysInYear = (eYear % 4 == 3) ? 366 : 365;
      daysDiff += daysInYear;
    }
  }
  return [eYear, (daysDiff ~/ 30) + 1, (daysDiff % 30) + 1];
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));

  if (!kIsWeb) {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

  runApp(MezgebeMihretApp(seenOnboarding: seenOnboarding));
}

class MezgebeMihretApp extends StatefulWidget {
  final bool seenOnboarding;
  const MezgebeMihretApp({super.key, required this.seenOnboarding});

  @override
  State createState() => _MezgebeMihretAppState();
}

class _MezgebeMihretAppState extends State<MezgebeMihretApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = !widget.seenOnboarding;
    _loadThemePreference();
  }

  Future _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    bool isDark = prefs.getBool('is_dark') ?? true;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
        prefs.setBool('is_dark', true);
      } else {
        _themeMode = ThemeMode.light;
        prefs.setBool('is_dark', false);
      }
    });
  }

  Future completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _themeMode == ThemeMode.dark;
    return MaterialApp(
      title: 'መዝገበ ምህረት ካላንደር',
      theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF4F6F9), primaryColor: Colors.blue[800]),
      darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF121212), primaryColor: Colors.blue[400]),
      themeMode: _themeMode,
      home: _showOnboarding
          ? OnboardingScreen(isDark: isDark, onFinish: completeOnboarding)
          : CalendarHomePage(toggleTheme: toggleTheme, isDark: isDark),
      debugShowCheckedModeBanner: false,
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.isDark, required this.onFinish});

  @override
  State createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List _pages = [
    {
      "icon": Icons.calendar_month_rounded,
      "color": Colors.blueAccent,
      "title": "እንኳን ወደ መዝገበ ምህረት በደህና መጡ!",
      "subtitle": "የኢትዮጵያ እና የፈረንጆች (Gregorian) የቀን መቁጠሪያዎችን ከውብ የግዕዝ ቁጥሮች ጋር በአንድ ላይ የያዘ ዘመናዊ መተግበሪያ።",
    },
    {
      "icon": Icons.auto_awesome_rounded,
      "color": Colors.orangeAccent,
      "title": "በዓላት እና መንፈሳዊ ጉባኤያት",
      "subtitle": "ዓመታዊ በዓላትን፣ አጽዋማትን እና ልዩ ልዩ መንፈሳዊ መርሐ-ግብሮችን በቀላሉ ይከታተሉ፤ አዳዲስ መርሐ-ግብሮችም በራሳቸው ይዘምናሉ።",
    },
    {
      "icon": Icons.notifications_active_rounded,
      "color": Colors.greenAccent,
      "title": "ቅድመ-ማስታወሻ ደወል (Alarm)",
      "subtitle": "መርሐ-ግብሮች እንዳያመልጡዎት ከ 2 ቀን በፊት፣ ከ 1 ቀን በፊት እና በዕለቱ በሰዓቱ አፑ በራሱ ደውሎ ያስታውስዎታል፤ የራስዎንም ማስታወሻ መመዝገብ ይችላሉ።",
    },
    {
      "icon": Icons.swap_horiz_rounded,
      "color": Colors.purpleAccent,
      "title": "ፈጣን የቀን መቀየሪያ",
      "subtitle": "ማንኛውንም ቀን፣ ወር እና ዓመተ ምህረት ከኢትዮጵያ ወደ ፈረንጆች ወይም ከፈረንጆች ወደ ኢትዮጵያ አቆጣጠር ከነዕለቱ በቅጽበት ይቀይሩ።",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9);
    final Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    final Color primaryColor = isDark ? Colors.blue[400]! : Colors.blue[800]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("መዝገበ ምህረት", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: widget.onFinish,
                      child: Text("ዝለል (Skip)", style: TextStyle(color: subTextColor, fontWeight: FontWeight.w600, fontSize: 14)),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final Map page = _pages[index] as Map;
                  final Color iconColor = page["color"] as Color;
                  final IconData iconData = page["icon"] as IconData;
                  final String titleStr = page["title"].toString();
                  final String subStr = page["subtitle"].toString();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 165,
                          height: 165,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cardBg,
                            boxShadow: [BoxShadow(color: iconColor.withOpacity(0.25), blurRadius: 30, spreadRadius: 6)],
                            border: Border.all(color: iconColor.withOpacity(0.4), width: 2.5),
                          ),
                          child: Center(child: Icon(iconData, size: 80, color: iconColor)),
                        ),
                        const SizedBox(height: 40),
                        Text(titleStr, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900, height: 1.3)),
                        const SizedBox(height: 16),
                        Text(subStr, textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 15, height: 1.5)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      bool isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 9,
                        width: isActive ? 28 : 9,
                        decoration: BoxDecoration(
                          color: isActive ? primaryColor : (isDark ? Colors.white24 : Colors.black26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                        } else {
                          widget.onFinish();
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1 ? "ጀምር (Get Started)" : "ቀጣይ (Next)",
                            style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == _pages.length - 1 ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarHomePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;
  const CalendarHomePage({super.key, required this.toggleTheme, required this.isDark});

  @override
  State createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage> with WidgetsBindingObserver {
  final String remoteJsonUrl = "https://raw.githubusercontent.com/abelo16/mezgebe-events/main/events.json";
  bool isSyncing = false;
  bool hasSyncedSuccessfully = false;
  Timer? _autoSyncTimer;

  List getEthiopicDate() {
    final now = DateTime.now();
    List eth = gcToEth(now.year, now.month, now.day);
    return [(eth[1] as int) - 1, eth[2] as int];
  }

  Map eventsDb = {
    "መስከረም 1": [{"title": "እንቁጣጣሽ (አዲስ ዓመት)", "type": "holiday"}, {"title": "በዓለ ሐራኤል (እግዚአብሔር አብ)", "type": "holiday"}],
    "መስከረም 4": [{"title": "የዓመቱ የጸሎት መርሐ ግብር", "type": "personal", "time": "09:00 AM"}],
    "መስከረም 9": [{"title": "የአንድነት ጉባዬ", "type": "personal", "time": "09:00 AM"}],
    "መስከረም 17": [{"title": "የመስቀል በዓል", "type": "holiday"}],
    "መስከረም 25": [{"title": "ጉባዔ ቄርሎስ", "type": "personal", "time": "02:00 PM"}],
    "ጥቅምት 17": [{"title": "ቅዱስ ማርቆስ መታሰቢያ", "type": "holiday"}],
    "ጥቅምት 30": [{"title": "የምክረ አበው", "type": "personal", "time": "10:00 AM"}],
    "ህዳር 5": [{"title": "የአንድነት ጉባዬ", "type": "personal", "time": "09:00 AM"}],
    "ህዳር 21": [{"title": "ጽዮን ማርያም (በዓለ እመቤታችን)", "type": "holiday"}],
    "ታህሳስ 29": [{"title": "በዓለ ልደት (ገና)", "type": "holiday"}],
    "ጥር 11": [{"title": "በዓለ ጥምቀት", "type": "holiday"}],
    "ጥር 17": [{"title": "የባለ ትዳር እና የሠራተኞች ጉባኤ", "type": "personal", "time": "04:30 PM"}],
    "የካቲት 29": [{"title": "ዐቢይ ጾም (ሁዳዴ) መግቢያ", "type": "holiday"}],
    "ሚያዝያ 24": [{"title": "ትንሣኤ (ፋሲካ)", "type": "holiday"}],
  };

  final List ethYears = List.generate(11, (index) => (2018 + index).toString());
  final List gcYears = List.generate(11, (index) => (2025 + index).toString());

  String calendarType = "ኢትዮጵያዊ";
  int monthIndex = 0;
  int yearIndex = 1;
  String selectedDate = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final ethDate = getEthiopicDate();
    monthIndex = ethDate[0] as int;
    selectedDate = "${ethMonths[monthIndex]} ${ethDate[1]}";
    _initializeDataAndAlarms();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (!hasSyncedSuccessfully && !isSyncing) fetchRemoteEvents(showMessage: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !hasSyncedSuccessfully && !isSyncing) {
      fetchRemoteEvents(showMessage: false);
    }
  }

  Future _initializeDataAndAlarms() async {
    await requestPermissions();
    await _loadSavedEvents();
    await fetchRemoteEvents();
  }

  Future _loadSavedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('saved_events_db');
    if (savedData != null) {
      try {
        Map decoded = jsonDecode(savedData) as Map;
        setState(() {
          eventsDb = decoded.map((key, value) => MapEntry(key.toString(), List.from(value as List)));
        });
      } catch (e) {}
    }
    scheduleAllAutomatedAlarms();
  }

  Future _saveEventsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_events_db', jsonEncode(eventsDb));
    scheduleAllAutomatedAlarms();
  }

  Future fetchRemoteEvents({bool showMessage = false}) async {
    setState(() => isSyncing = true);
    final List urlsToTry = [
      "$remoteJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}",
      "https://cdn.jsdelivr.net/gh/abelo16/mezgebe-events@main/events.json?t=${DateTime.now().millisecondsSinceEpoch}",
    ];
    Map? parsedData;

    for (var url in urlsToTry) {
      try {
        final response = await http.get(Uri.parse(url.toString()), headers: {"Cache-Control": "no-cache"}).timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          String rawText = utf8.decode(response.bodyBytes, allowMalformed: true);
          int startIdx = rawText.indexOf('{');
          int endIdx = rawText.lastIndexOf('}');
          if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
            rawText = rawText.substring(startIdx, endIdx + 1);
          }
          rawText = rawText.replaceAll('\u00A0', ' ').replaceAll('\uFEFF', '');
          parsedData = jsonDecode(rawText) as Map;
          break;
        }
      } catch (e) {}
    }

    if (parsedData != null) {
      hasSyncedSuccessfully = true;
      setState(() {
        Map mergedDb = {};
        eventsDb.forEach((date, list) {
          if (list is List) {
            var userItems = list.where((item) => item is Map && item['userAdded'] == true).toList();
            if (userItems.isNotEmpty) mergedDb[date.toString()] = List.from(userItems);
          }
        });
        parsedData!.forEach((date, list) {
          String cleanDate = date.toString().trim();
          if (list is List) {
            if (mergedDb[cleanDate] == null) mergedDb[cleanDate] = [];
            (mergedDb[cleanDate] as List).insertAll(0, List.from(list));
          }
        });
        eventsDb = mergedDb;
      });
      try { await _saveEventsLocally(); } catch (e) {}
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ መርሐ-ግብሮች በተሳካ ሁኔታ ተሻሽለዋል!"), backgroundColor: Colors.green));
      }
    } else if (showMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("⚠️ የኢንተርኔት ግንኙነት የለም! እባክዎ ዳታ ወይም ዋይፋይ አብርተው ይሞክሩ።"),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 4),
      ));
    }
    if (mounted) setState(() => isSyncing = false);
  }

  Future requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final androidImpl = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      final iosImpl = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future scheduleAllAutomatedAlarms() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
    int notificationId = 1;
    eventsDb.forEach((dateStr, events) {
      List parts = dateStr.toString().split(' ');
      if (parts.length != 2) return;
      int mIndex = ethMonths.indexOf(parts[0].toString());
      int day = int.tryParse(parts[1].toString()) ?? 1;
      if (mIndex == -1 || events is! List) return;

      DateTime now = DateTime.now();
      DateTime meskerem1 = DateTime(now.year, 9, 11);
      if (now.isBefore(meskerem1)) meskerem1 = DateTime(now.year - 1, 9, 11);
      DateTime gcDate = meskerem1.add(Duration(days: (mIndex * 30) + (day - 1)));

      for (var event in events) {
        if (event is! Map || event["type"] != "personal" || !event.containsKey("time")) continue;
        String title = event["title"].toString();
        int hour = 10, min = 0;
        try {
          final timeParts = event["time"].toString().trim().split(' ');
          final hm = timeParts[0].split(':');
          hour = int.parse(hm[0]);
          min = int.parse(hm[1]);
          if (timeParts.length > 1) {
            if (timeParts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
            if (timeParts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
          }
        } catch (e) {}

        DateTime exactEventTime = DateTime(gcDate.year, gcDate.month, gcDate.day, hour, min);
        DateTime d2 = gcDate.subtract(const Duration(days: 2));
        DateTime t2 = DateTime(d2.year, d2.month, d2.day, 7, 0);
        if (t2.isAfter(now)) _scheduleExactAlarm(notificationId++, title, "ለ '$title' 2 ቀን ቀረው!", t2);

        DateTime d1 = gcDate.subtract(const Duration(days: 1));
        DateTime t1 = DateTime(d1.year, d1.month, d1.day, 7, 0);
        if (t1.isAfter(now)) _scheduleExactAlarm(notificationId++, title, "ለ '$title' 1 ቀን ቀረው!", t1);

        if (exactEventTime.isAfter(now)) _scheduleExactAlarm(notificationId++, title, "ዛሬ ነው! '$title' አሁን ደርሷል!", exactEventTime);
      }
    });
  }

  Future _scheduleExactAlarm(int id, String title, String body, DateTime time) async {
    if (kIsWeb) return;
    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(time, tz.local);
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'auto_events', 'አውቶማቲክ መርሐ-ግብሮች',
      importance: Importance.max, priority: Priority.high, playSound: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true,
    );
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id, '⏰ መዝገበ ምህረት', body, tzScheduledDate,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void toggleCalendar() {
    setState(() {
      final now = DateTime.now();
      if (calendarType == "ኢትዮጵያዊ") {
        calendarType = "ግሪጎሪያን";
        monthIndex = now.month - 1;
        yearIndex = 1;
        selectedDate = "${gcMonths[monthIndex]} ${now.day}";
      } else {
        calendarType = "ኢትዮጵያዊ";
        final ethDate = getEthiopicDate();
        monthIndex = ethDate[0] as int;
        yearIndex = 1;
        selectedDate = "${ethMonths[monthIndex]} ${ethDate[1]}";
      }
    });
  }

  void jumpToDate(String dateStr) {
    List parts = dateStr.split(' ');
    int mIndex = ethMonths.indexOf(parts[0].toString());
    if (mIndex != -1) {
      setState(() {
        calendarType = "ኢትዮጵያዊ";
        monthIndex = mIndex;
        selectedDate = dateStr;
      });
    }
    Navigator.pop(context);
  }

  bool isEventPassed(String dateStr) {
    List parts = dateStr.split(' ');
    if (parts.length != 2) return false;
    int mIndex = ethMonths.indexOf(parts[0].toString());
    int day = int.tryParse(parts[1].toString()) ?? 1;
    if (mIndex == -1) return false;
    final currentEth = getEthiopicDate();
    int curM = currentEth[0] as int;
    int curD = currentEth[1] as int;
    if (mIndex < curM) return true;
    if (mIndex == curM && day < curD) return true;
    return false;
  }

  Future _addOrEditNote({int? editIndex}) async {
    bool isEditing = editIndex != null;
    List currentList = (eventsDb[selectedDate] as List?) ?? [];
    var existingItem = isEditing ? currentList[editIndex] : null;
    TextEditingController titleController = TextEditingController(text: isEditing ? existingItem['title'].toString() : '');
    TimeOfDay? selectedTime = TimeOfDay.now();
    final bool isDark = widget.isDark;
    final Color primaryColor = isDark ? Colors.blue[400]! : Colors.blue[800]!;
    final Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: bgColor,
          title: Text(isEditing ? "ማስታወሻ ማስተካከያ" : "አዲስ የግል ማስታወሻ ($selectedDate)", style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "የማስታወሻ ርዕስ", labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54))),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[900] : Colors.blue[100], elevation: 0),
                onPressed: () async {
                  TimeOfDay? picked = await showTimePicker(context: context, initialTime: selectedTime ?? TimeOfDay.now());
                  if (picked != null) { selectedTime = picked; setDialogState(() {}); }
                },
                icon: Icon(Icons.access_time, color: isDark ? Colors.white : Colors.blue[800]),
                label: Text(selectedTime == null ? "ሰዓት ምረጥ" : selectedTime!.format(context), style: TextStyle(color: isDark ? Colors.white : Colors.blue[800], fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("ተወው", style: TextStyle(color: Colors.red))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () {
                if (titleController.text.isNotEmpty && selectedTime != null) {
                  String amPm = selectedTime!.period == DayPeriod.am ? "AM" : "PM";
                  int h = selectedTime!.hourOfPeriod == 0 ? 12 : selectedTime!.hourOfPeriod;
                  String timeString = "${h.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')} $amPm";
                  setState(() {
                    if (eventsDb[selectedDate] == null) eventsDb[selectedDate] = [];
                    var newEvent = {"title": titleController.text, "type": "personal", "time": timeString, "userAdded": true};
                    if (isEditing) (eventsDb[selectedDate] as List)[editIndex] = newEvent;
                    else (eventsDb[selectedDate] as List).add(newEvent);
                  });
                  _saveEventsLocally();
                  Navigator.pop(context);
                }
              },
              child: Text(isEditing ? "አስተካክል" : "መዝግብ", style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteUserNote(int index) {
    setState(() {
      (eventsDb[selectedDate] as List).removeAt(index);
      if ((eventsDb[selectedDate] as List).isEmpty) eventsDb.remove(selectedDate);
    });
    _saveEventsLocally();
  }

  void _showAboutDialog() {
    final bool isDark = widget.isDark;
    final Color primaryColor = isDark ? Colors.blue[400]! : Colors.blue[800]!;
    final Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [Icon(Icons.info_outline_rounded, color: primaryColor, size: 26), const SizedBox(width: 8), Text("About App", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Mezgebe Mihret Calendar", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text("Version 1.0.0", style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text("An Ethiopian & Gregorian calendar app with automated spiritual event reminders and personal schedule management.", style: TextStyle(color: textColor, fontSize: 13.5, height: 1.4)),
            const Divider(height: 24),
            Text("Developed by: Abel Adugna", style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text("Email: abel45sd@gmail.com", style: TextStyle(color: subTextColor, fontSize: 12.5)),
            const SizedBox(height: 12),
            Center(child: Text("© 2026 Mezgebe Mihret. All rights reserved.", style: TextStyle(color: subTextColor, fontSize: 11))),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)))],
      ),
    );
  }

  String _formatSelectedDateTitle(String dateStr) {
    if (calendarType != "ኢትዮጵያዊ") return dateStr;
    List parts = dateStr.split(' ');
    if (parts.length != 2) return dateStr;
    int? day = int.tryParse(parts[1].toString());
    return day != null ? "${parts[0]} ${toGeez(day)} ($day)" : dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    final Color primaryColor = isDark ? Colors.blue[400]! : Colors.blue[800]!;
    final Color containerBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    final Color dividerColor = isDark ? Colors.white24 : Colors.blue[200]!;
    final Color selectedBg = isDark ? Colors.blue[700]! : Colors.blue[600]!;
    final Color eventCardBg = isDark ? const Color(0xFF2A2D34) : Colors.blue[50]!;
    final Color eventCardBorder = isDark ? Colors.blue[900]! : Colors.blue[200]!;
    final Color holidayCardBg = isDark ? const Color(0xFF2D2A24) : Colors.grey[100]!;
    final Color holidayCardBorder = isDark ? Colors.orange[900]! : Colors.grey[300]!;

    final List mList = calendarType == "ኢትዮጵያዊ" ? ethMonths : gcMonths;
    final List yList = calendarType == "ኢትዮጵያዊ" ? ethYears : gcYears;
    final List weekDays = calendarType == "ኢትዮጵያዊ" ? ["እሁ", "ሰኞ", "ማክ", "ረቡ", "ሐሙ", "አር", "ቅዳ"] : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    int daysCount = 30, startOffset = 0, currentEYear = int.parse(ethYears[yearIndex].toString());

    if (calendarType == "ኢትዮጵያዊ") {
      int eMonth = monthIndex + 1;
      daysCount = (eMonth == 13) ? ((currentEYear % 4 == 3) ? 6 : 5) : 30;
      DateTime firstDayGc = ethToGc(currentEYear, eMonth, 1);
      startOffset = firstDayGc.weekday == 7 ? 0 : firstDayGc.weekday;
    } else {
      int gYear = int.parse(gcYears[yearIndex].toString()), gMonth = monthIndex + 1;
      daysCount = DateTime(gYear, gMonth + 1, 0).day;
      DateTime firstDay = DateTime(gYear, gMonth, 1);
      startOffset = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    }

    List<Widget> holidayWidgets = [], personalWidgets = [];
    eventsDb.forEach((date, events) {
      if (events is List) {
        for (var e in events) {
          if (e is! Map) continue;
          bool passed = isEventPassed(date.toString());
          Widget tile = ListTile(
            leading: Icon(e['type'] == 'holiday' ? Icons.star : Icons.notifications_active, color: e['type'] == 'holiday' ? Colors.orange : Colors.blue[500]),
            title: Row(children: [
              Expanded(child: Text(e['title'].toString(), style: TextStyle(color: textColor, fontWeight: FontWeight.w500))),
              if (passed) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red[900], borderRadius: BorderRadius.circular(4)), child: const Text("አልፏል", style: TextStyle(color: Colors.white, fontSize: 10))),
            ]),
            subtitle: Text(date.toString(), style: TextStyle(color: subTextColor)),
            onTap: () => jumpToDate(date.toString()),
          );
          if (e['type'] == 'holiday') holidayWidgets.add(tile);
          else if (e['type'] == 'personal') personalWidgets.add(tile);
        }
      }
    });

    List selectedEvents = (eventsDb[selectedDate] as List?) ?? [];

    return Scaffold(
      drawer: Drawer(
        backgroundColor: containerBg,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: isDark ? Colors.blue[900] : Colors.blue[800]),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.calendar_month, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text("መዝገበ ምህረት ካላንደር", style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                  Text("የበዓላት እና መርሐ-ግብሮች ማውጫ", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ExpansionTile(leading: const Icon(Icons.star, color: Colors.orange), title: Text("በዓላት", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)), children: holidayWidgets),
            ExpansionTile(leading: Icon(Icons.notifications_active, color: primaryColor), title: Text("መርሐ ግብራት", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)), children: personalWidgets),
            const Divider(),
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded, color: primaryColor),
              title: Text("ቀን መቀየሪያ", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text("ወደ ኢትዮጵያ / ወደ ግሪጎሪያን", style: TextStyle(color: subTextColor, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => DateConverterScreen(isDark: isDark)));
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_stories_outlined, color: primaryColor),
              title: Text("የአፑ ማስተዋወቂያ", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text("Welcome Guide", style: TextStyle(color: subTextColor, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => OnboardingScreen(isDark: isDark, onFinish: () => Navigator.pop(context))));
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: primaryColor),
              title: Text("About", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(context); _showAboutDialog(); },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditNote(),
        backgroundColor: primaryColor,
        child: Icon(Icons.add, color: isDark ? Colors.black : Colors.white, size: 30),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(builder: (context) => IconButton(icon: Icon(Icons.menu, color: primaryColor, size: 28), onPressed: () => Scaffold.of(context).openDrawer())),
                  Expanded(child: Text("መዝገበ ምህረት ካላንደር", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor))),
                  Row(
                    children: [
                      isSyncing
                          ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                          : IconButton(icon: Icon(Icons.sync, color: primaryColor, size: 22), onPressed: () => fetchRemoteEvents(showMessage: true)),
                      IconButton(icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: primaryColor, size: 22), onPressed: widget.toggleTheme),
                      ElevatedButton(
                        onPressed: toggleCalendar,
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[700] : Colors.blue[600], padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero, elevation: 0),
                        child: Text(calendarType == "ኢትዮጵያዊ" ? "GC" : "EC", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
              Divider(color: dividerColor, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: Icon(Icons.chevron_left, color: primaryColor), onPressed: () => setState(() { if (monthIndex > 0) monthIndex--; else { monthIndex = mList.length - 1; if (yearIndex > 0) yearIndex--; } })),
                  Text("${mList[monthIndex]} ${yList[yearIndex]}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                  IconButton(icon: Icon(Icons.chevron_right, color: primaryColor), onPressed: () => setState(() { if (monthIndex < mList.length - 1) monthIndex++; else { monthIndex = 0; if (yearIndex < yList.length - 1) yearIndex++; } })),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: containerBg, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)]),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: weekDays.map((wd) => Expanded(child: Center(child: Text(wd.toString(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))))).toList()),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.85),
                      itemCount: daysCount + startOffset,
                      itemBuilder: (context, index) {
                        if (index < startOffset) return Container();
                        int dayNum = index - startOffset + 1;
                        String dateStr = "${mList[monthIndex]} $dayNum";
                        List dayEvents = (eventsDb[dateStr] as List?) ?? [];
                        bool hasEvent = dayEvents.isNotEmpty;
                        bool hasPersonal = dayEvents.any((e) => e is Map && e["type"] == "personal");
                        bool isSelected = selectedDate == dateStr;
                        Color dotColor = hasPersonal ? Colors.blue : (hasEvent ? Colors.orange : Colors.transparent);
                        Color cellBgColor = isSelected ? selectedBg : (hasEvent ? (isDark ? const Color(0xFF2A2D34) : Colors.blue[50]!) : Colors.transparent);
                        String mainDayText = calendarType == "ኢትዮጵያዊ" ? toGeez(dayNum) : "$dayNum";
                        String subGcDayText = calendarType == "ኢትዮጵያዊ" ? "${ethToGc(currentEYear, monthIndex + 1, dayNum).day}" : "";

                        return GestureDetector(
                          onTap: () => setState(() => selectedDate = dateStr),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: cellBgColor, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(mainDayText, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isSelected ? Colors.white : textColor, height: 1.1)),
                                if (calendarType == "ኢትዮጵያዊ") Text(subGcDayText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white70 : subTextColor)),
                                const SizedBox(height: 2),
                                Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: containerBg, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("📅 ${_formatSelectedDateTitle(selectedDate)} መርሐ-ግብሮች", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: selectedEvents.isEmpty
                            ? Text("በዚህ ዕለት የተመዘገበ ልዩ መርሐ-ግብር የለም።", style: TextStyle(color: subTextColor))
                            : ListView.builder(
                                itemCount: selectedEvents.length,
                                itemBuilder: (context, index) {
                                  var item = selectedEvents[index];
                                  if (item is! Map) return const SizedBox();
                                  bool isPersonal = item["type"] == "personal";
                                  bool isUserAdded = item["userAdded"] == true;
                                  bool passed = isEventPassed(selectedDate);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(color: isPersonal ? eventCardBg : holidayCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: isPersonal ? eventCardBorder : holidayCardBorder)),
                                    child: Row(
                                      children: [
                                        Icon(isPersonal ? Icons.notifications_active : Icons.star, color: isPersonal ? primaryColor : Colors.orange, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text("${item['title']} ${isPersonal ? '⏰ (${item["time"]})' : ''}", style: TextStyle(color: textColor, fontWeight: FontWeight.w500))),
                                        if (passed) Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red[900], borderRadius: BorderRadius.circular(4)), child: const Text("አልፏል", style: TextStyle(color: Colors.white, fontSize: 10))),
                                        if (isUserAdded) ...[
                                          IconButton(icon: Icon(Icons.edit, size: 18, color: primaryColor), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _addOrEditNote(editIndex: index)),
                                          const SizedBox(width: 8),
                                          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _deleteUserNote(index)),
                                        ]
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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

class DateConverterScreen extends StatefulWidget {
  final bool isDark;
  const DateConverterScreen({super.key, required this.isDark});

  @override
  State createState() => _DateConverterScreenState();
}

class _DateConverterScreenState extends State<DateConverterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int gcMonth = 11, ethMonth = 3;
  late TextEditingController gcDayController, gcYearController, ethDayController, ethYearController;
  String ethResultMain = "", ethResultSub = "", gcResultMain = "", gcResultSub = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    gcMonth = now.month;
    gcDayController = TextEditingController(text: "${now.day}");
    gcYearController = TextEditingController(text: "${now.year}");
    List currentEth = gcToEth(now.year, now.month, now.day);
    ethMonth = currentEth[1] as int;
    ethDayController = TextEditingController(text: "${currentEth[2]}");
    ethYearController = TextEditingController(text: "${currentEth[0]}");
    _convertToEthiopian();
    _convertToGregorian();
  }

  @override
  void dispose() {
    _tabController.dispose();
    gcDayController.dispose();
    gcYearController.dispose();
    ethDayController.dispose();
    ethYearController.dispose();
    super.dispose();
  }

  void _convertToEthiopian() {
    int day = int.tryParse(gcDayController.text.trim()) ?? 1;
    int year = int.tryParse(gcYearController.text.trim()) ?? 2026;
    if (day < 1) day = 1;
    int maxDays = DateTime(year, gcMonth + 1, 0).day;
    if (day > maxDays) { day = maxDays; gcDayController.text = "$day"; }
    DateTime gcDate = DateTime(year, gcMonth, day);
    List eth = gcToEth(year, gcMonth, day);
    int eY = eth[0] as int, eM = eth[1] as int, eD = eth[2] as int;
    String weekDay = ethWeekDaysFull[gcDate.weekday - 1].toString();
    setState(() {
      ethResultMain = "${ethMonths[eM - 1]} $eD ቀን $eY ዓ.ም";
      ethResultSub = "ዕለተ $weekDay (በግዕዝ፦ ${ethMonths[eM - 1]} ${toGeez(eD)})";
    });
  }

  void _convertToGregorian() {
    int day = int.tryParse(ethDayController.text.trim()) ?? 1;
    int year = int.tryParse(ethYearController.text.trim()) ?? 2019;
    if (day < 1) day = 1;
    int maxDays = (ethMonth == 13) ? ((year % 4 == 3) ? 6 : 5) : 30;
    if (day > maxDays) { day = maxDays; ethDayController.text = "$day"; }
    DateTime gc = ethToGc(year, ethMonth, day);
    setState(() {
      gcResultMain = "${gcMonths[gc.month - 1]} ${gc.day}, ${gc.year}";
      gcResultSub = "${gcWeekDaysFull[gc.weekday - 1]} (${ethWeekDaysFull[gc.weekday - 1]})";
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    final Color appBarBg = isDark ? const Color(0xFF1565C0) : Colors.blue[800]!;
    final Color primaryBtnColor = isDark ? Colors.blue[600]! : Colors.blue[800]!;
    final Color scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9);
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white60 : Colors.black54;
    final Color dividerColor = isDark ? Colors.white24 : Colors.black12;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Text("ቀን መቀየሪያ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [Tab(text: "ወደ ኢትዮጵያ"), Tab(text: "ወደ ግሪጎሪያን")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConverterTab("ከግሪጎሪያን ወደ ኢትዮጵያ ቀን ለመለወጥ", gcMonth, 12, true, (v) { if (v != null) setState(() => gcMonth = v as int); }, gcDayController, gcYearController, () { FocusScope.of(context).unfocus(); _convertToEthiopian(); }, ethResultMain, ethResultSub, textColor, subTextColor, dividerColor, primaryBtnColor, isDark),
          _buildConverterTab("ከኢትዮጵያ ወደ ግሪጎሪያን ቀን ለመለወጥ", ethMonth, 13, false, (v) { if (v != null) setState(() => ethMonth = v as int); }, ethDayController, ethYearController, () { FocusScope.of(context).unfocus(); _convertToGregorian(); }, gcResultMain, gcResultSub, textColor, subTextColor, dividerColor, primaryBtnColor, isDark),
        ],
      ),
    );
  }

  Widget _buildConverterTab(String subtitle, int selectedMonth, int maxMonths, bool isGcInput, ValueChanged onMonthChanged, TextEditingController dayCtrl, TextEditingController yearCtrl, VoidCallback onConvert, String resMain, String resSub, Color textColor, Color subTextColor, Color dividerColor, Color btnColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Text("ወር", style: TextStyle(color: subTextColor, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton(
                        value: selectedMonth,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        icon: Icon(Icons.arrow_drop_down, color: subTextColor),
                        items: List.generate(maxMonths, (idx) {
                          int m = idx + 1;
                          String label = isGcInput ? "$m (${gcMonths[m - 1].toString().substring(0, 3)})" : "$m (${ethMonths[m - 1]})";
                          return DropdownMenuItem(value: m, child: Center(child: Text(label, style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold))));
                        }),
                        onChanged: onMonthChanged,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Text("ቀን", style: TextStyle(color: subTextColor, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(controller: dayCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8))),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Text("አመት", style: TextStyle(color: subTextColor, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(controller: yearCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8))),
                  ],
                ),
              ),
            ],
          ),
          Divider(color: dividerColor, thickness: 1, height: 16),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onConvert,
              style: ElevatedButton.styleFrom(backgroundColor: btnColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 4),
              child: const Text("ለውጥ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
          Text(resMain, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(resSub, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[800], fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}