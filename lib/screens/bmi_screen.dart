// lib/screens/bmi_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/api_service.dart';

class BmiScreen extends StatefulWidget {
  const BmiScreen({super.key});
  @override
  State<BmiScreen> createState() => _BmiScreenState();
}

class _BmiScreenState extends State<BmiScreen> {
  double _height = 170;
  double _weight = 65;
  int _age = 25;
  String _gender = 'Kadın';
  double? _bmi;
  String _category = '';
  Color _categoryColor = AppTheme.primary;
  String _advice = '';
  bool _loadingAdvice = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _height = prefs.getDouble('height') ?? 170;
      _weight = prefs.getDouble('weight') ?? 65;
      _age = prefs.getInt('age') ?? 25;
      _gender = prefs.getString('gender') ?? 'Kadın';
    });
    _calculate();
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('height', _height);
    await prefs.setDouble('weight', _weight);
    await prefs.setInt('age', _age);
    await prefs.setString('gender', _gender);
  }

  void _calculate() {
    final heightM = _height / 100;
    final bmi = _weight / (heightM * heightM);
    String cat;
    Color color;

    if (bmi < 18.5) {
      cat = 'Zayıf';
      color = Colors.blue;
    } else if (bmi < 25) {
      cat = 'Normal Kilolu ✓';
      color = AppTheme.primary;
    } else if (bmi < 30) {
      cat = 'Fazla Kilolu';
      color = Colors.orange;
    } else {
      cat = 'Obez';
      color = Colors.red;
    }

    setState(() {
      _bmi = bmi;
      _category = cat;
      _categoryColor = color;
      _advice = '';
    });

    _saveProfile();
  }

  Future<void> _getAiAdvice() async {
    setState(() => _loadingAdvice = true);
    final question =
        'Kullanıcı bilgileri: Boy ${_height.toInt()}cm, Kilo ${_weight.toInt()}kg, '
        'Yaş $_age, Cinsiyet $_gender, BMI ${_bmi!.toStringAsFixed(1)} ($_category). '
        'Bu kişiye özel kısa ve pratik beslenme tavsiyeleri ver.';

    final answer = await ApiService.chat(question);
    setState(() {
      _advice = answer;
      _loadingAdvice = false;
    });
  }

  double get _idealWeightMin => 18.5 * (_height / 100) * (_height / 100);
  double get _idealWeightMax => 24.9 * (_height / 100) * (_height / 100);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BMI Hesaplama',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Giriş kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(children: [
              // Cinsiyet
              Row(children: ['Kadın', 'Erkek'].map((g) => Expanded(
                child: GestureDetector(
                  onTap: () { setState(() => _gender = g); _calculate(); },
                  child: Container(
                    margin: EdgeInsets.only(right: g == 'Kadın' ? 6 : 0, left: g == 'Erkek' ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _gender == g ? AppTheme.primary : const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      g == 'Kadın' ? '👩 Kadın' : '👨 Erkek',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: _gender == g ? Colors.white : AppTheme.textMid,
                      ),
                    ),
                  ),
                ),
              )).toList()),
              const SizedBox(height: 16),

              // Boy slider
              _sliderRow('Boy', '${_height.toInt()} cm', _height, 100, 220, (v) {
                setState(() => _height = v);
                _calculate();
              }),
              const SizedBox(height:12),

              // Kilo slider
              _sliderRow('Kilo', '${_weight.toInt()} kg', _weight, 30, 150, (v) {
                setState(() => _weight = v);
                _calculate();
              }),
              const SizedBox(height: 12),

              // Yaş slider
              _sliderRow('Yaş', '$_age', _age.toDouble(), 10, 90, (v) {
                setState(() => _age = v.toInt());
                _calculate();
              }),
            ]),
          ),
          const SizedBox(height: 16),

          // BMI Sonuç kartı
          if (_bmi != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Column(children: [
                Text(_bmi!.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 52, fontWeight: FontWeight.w700,
                      color: _categoryColor,
                    )),
                Text(_category,
                    style: TextStyle(fontSize: 16, color: _categoryColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),

                // BMI skalası
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(children: [
                    Expanded(flex: 2, child: Container(height: 8, color: Colors.blue[300])),
                    Expanded(flex: 3, child: Container(height: 8, color: AppTheme.primary)),
                    Expanded(flex: 2, child: Container(height: 8, color: Colors.orange)),
                    Expanded(flex: 2, child: Container(height: 8, color: Colors.red)),
                  ]),
                ),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Zayıf', 'Normal', 'Fazla', 'Obez']
                        .map((s) => Text(s, style: const TextStyle(fontSize: 9, color: Colors.grey)))
                        .toList()),
                const SizedBox(height: 12),

                // İdeal kilo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.flag_rounded, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'İdeal kilo aralığın: ${_idealWeightMin.toInt()} – ${_idealWeightMax.toInt()} kg',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMid, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // AI Tavsiye butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loadingAdvice ? null : _getAiAdvice,
                    icon: _loadingAdvice
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(_loadingAdvice ? 'Analiz ediliyor...' : '🤖 AI\'dan Kişisel Tavsiye Al'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // AI cevabı
                if (_advice.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FAF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('🥗', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_advice,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textDark, height: 1.5))),
                    ]),
                  ),
                ],
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _sliderRow(String label, String value, double current,
      double min, double max, ValueChanged<double> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMid)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE1F5EE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        ),
      ]),
      Slider(
        value: current, min: min, max: max,
        activeColor: AppTheme.primary,
        inactiveColor: AppTheme.border,
        onChanged: onChanged,
      ),
    ]);
  }
}