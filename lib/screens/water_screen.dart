// lib/screens/water_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../theme.dart';
import '../services/notification_service.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});
  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen>
    with SingleTickerProviderStateMixin {
  double _current = 0;
  double _goal = 2500;
  List<Map<String, dynamic>> _logs = [];
  late AnimationController _waveController;

  Timer? _reminderTimer;
  int _reminderMinutes = 120;
  bool _reminderActive = false;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    setState(() {
      _current = prefs.getDouble('water_$today') ?? 0;
      _goal = prefs.getDouble('water_goal') ?? 2500;
      final saved = prefs.getString('water_logs_$today');
      _logs = saved != null
          ? List<Map<String, dynamic>>.from(jsonDecode(saved))
          : [];
    });
  }

  Future<void> _addWater(double ml) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _current = (_current + ml).clamp(0, _goal * 1.5);
      _logs.insert(0, {'ml': ml.toInt(), 'time': timeStr});
    });

    await prefs.setDouble('water_$today', _current);
    await prefs.setString('water_logs_$today', jsonEncode(_logs));

    if (_current >= _goal) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Günlük su hedefine ulaştın!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _removeLog(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final ml = _logs[index]['ml'] as int;
    setState(() {
      _current = (_current - ml).clamp(0, double.infinity);
      _logs.removeAt(index);
    });
    await prefs.setDouble('water_$today', _current);
    await prefs.setString('water_logs_$today', jsonEncode(_logs));
  }

  void _startReminder(int minutes) {
    _reminderTimer?.cancel();
    setState(() {
      _reminderActive = true;
      _reminderMinutes = minutes;
      _remainingSeconds = minutes * 60;
    });

    NotificationService.scheduleRepeatingReminder(minutes);

    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        setState(() => _remainingSeconds = _reminderMinutes * 60);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💧 Su içme zamanı!'),
            backgroundColor: AppTheme.primary,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _stopReminder() {
    _reminderTimer?.cancel();
    NotificationService.cancelReminders();
    setState(() {
      _reminderActive = false;
      _remainingSeconds = 0;
    });
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}s ${m.toString().padLeft(2, '0')}d';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showReminderDialog() {
    int selected = _reminderMinutes;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('⏰ Hatırlatıcı Ayarla',
              style: TextStyle(color: AppTheme.textDark, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Ne sıklıkla hatırlatayım?',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            ...[1, 30, 60, 90, 120, 180].map((min) => GestureDetector(
              onTap: () => setS(() => selected = min),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected == min
                      ? AppTheme.primary
                      : const Color(0xFFE1F5EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.timer,
                      size: 16,
                      color: selected == min
                          ? Colors.white
                          : AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    min == 1
                        ? '1 dakika (Test)'
                        : min == 30
                        ? '30 dakika'
                        : min == 60
                        ? '1 saat'
                        : min == 90
                        ? '1 saat 30 dakika'
                        : min == 120
                        ? '2 saat'
                        : '3 saat',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected == min
                          ? Colors.white
                          : AppTheme.textMid,
                    ),
                  ),
                  const Spacer(),
                  if (selected == min)
                    const Icon(Icons.check, size: 16, color: Colors.white),
                ]),
              ),
            )),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                const Text('İptal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                _startReminder(selected);
                Navigator.pop(ctx);
              },
              child:
              const Text('Başlat', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomDialog() {
    double custom = 250;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Özel Miktar',
            style: TextStyle(color: AppTheme.textDark)),
        content: StatefulBuilder(
          builder: (ctx, setS) =>
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${custom.toInt()} ml',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary)),
                Slider(
                  value: custom,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setS(() => custom = v),
                ),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
              const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              _addWater(custom);
              Navigator.pop(ctx);
            },
            child: const Text('Ekle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showGoalDialog() {
    double newGoal = _goal;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Günlük Hedef',
            style: TextStyle(color: AppTheme.textDark)),
        content: StatefulBuilder(
          builder: (ctx, setS) =>
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(newGoal / 1000).toStringAsFixed(1)} litre',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary)),
                Slider(
                  value: newGoal,
                  min: 1000,
                  max: 5000,
                  divisions: 16,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setS(() => newGoal = v),
                ),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
              const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('water_goal', newGoal);
              setState(() => _goal = newGoal);
              if (mounted) Navigator.pop(ctx);
            },
            child:
            const Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_current / _goal).clamp(0.0, 1.0);
    final remaining = (_goal - _current).clamp(0, _goal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Su Takibi',
            style:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (_reminderActive)
            GestureDetector(
              onTap: _stopReminder,
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(_formatTime(_remainingSeconds),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.close, color: Colors.white70, size: 12),
                ]),
              ),
            ),
          IconButton(
            icon: Icon(
              _reminderActive
                  ? Icons.notifications_active
                  : Icons.notifications_outlined,
              color: Colors.white,
            ),
            onPressed: _reminderActive ? _stopReminder : _showReminderDialog,
            tooltip: _reminderActive ? 'Hatırlatıcıyı Durdur' : 'Hatırlatıcı Ayarla',
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: _showGoalDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(children: [
              Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 120,
                  height: 160,
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (ctx, _) => CustomPaint(
                      painter:
                      _WaterPainter(pct, _waveController.value),
                    ),
                  ),
                ),
                Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${(pct * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: pct > 0.4
                                ? Colors.white
                                : AppTheme.primary,
                          )),
                      Text('${(_current / 1000).toStringAsFixed(1)}L',
                          style: TextStyle(
                            fontSize: 14,
                            color: pct > 0.4
                                ? Colors.white70
                                : AppTheme.textMid,
                          )),
                    ]),
              ]),
              const SizedBox(height: 12),
              Text(
                remaining > 0
                    ? '${(remaining / 1000).toStringAsFixed(1)} litre daha iç'
                    : '🎉 Hedefe ulaştın!',
                style:
                const TextStyle(fontSize: 14, color: AppTheme.textMid),
              ),
              const SizedBox(height: 4),
              Text('Hedef: ${(_goal / 1000).toStringAsFixed(1)} litre',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (_reminderActive) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5EE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.timer,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatTime(_remainingSeconds)} sonra hatırlatılacaksın',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMid),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Hızlı Ekle',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _addBtn('☕ 100ml', 100),
            const SizedBox(width: 8),
            _addBtn('🥛 200ml', 200),
            const SizedBox(width: 8),
            _addBtn('💧 300ml', 300),
            const SizedBox(width: 8),
            _addBtn('🍶 500ml', 500),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCustomDialog,
              icon: const Icon(Icons.edit, size: 16, color: AppTheme.primary),
              label: const Text('Özel Miktar Gir',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Bugünkü Kayıtlar',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
          ),
          const SizedBox(height: 8),
          if (_logs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: const Center(
                child: Text('Henüz kayıt yok. Su ekle! 💧',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
            )
          else
            ...List.generate(_logs.length, (i) {
              final log = _logs[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Row(children: [
                  const Icon(Icons.water_drop,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Text('${log['ml']} ml',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textDark)),
                  const Spacer(),
                  Text(log['time'],
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.primary)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _removeLog(i),
                    child: const Icon(Icons.close,
                        size: 16, color: Colors.grey),
                  ),
                ]),
              );
            }),
        ]),
      ),
    );
  }

  Widget _addBtn(String label, double ml) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _addWater(ml),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE1F5EE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _WaterPainter extends CustomPainter {
  final double fillPct;
  final double wave;
  _WaterPainter(this.fillPct, this.wave);

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final glassBorder = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(glassBorder, borderPaint);

    if (fillPct <= 0) return;

    final waterHeight = size.height * fillPct;
    final waterTop = size.height - waterHeight;

    final waterPath = Path();
    waterPath.moveTo(2, size.height - 2);
    waterPath.lineTo(2, waterTop + 8);

    for (double x = 0; x <= size.width; x++) {
      final y = waterTop +
          6 * _sin((x / size.width * 2 * 3.14159) + wave * 2 * 3.14159);
      waterPath.lineTo(x, y);
    }
    waterPath.lineTo(size.width - 2, size.height - 2);
    waterPath.close();

    final waterPaint = Paint()
      ..color = AppTheme.primary.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    canvas.clipRRect(glassBorder);
    canvas.drawPath(waterPath, waterPaint);
  }

  double _sin(double x) {
    x = x % (2 * 3.141592653589793);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(_WaterPainter old) => true;
}