// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _meals = [];
  double _totalCalories = 0;
  double _totalProtein = 0;
  double _totalCarbs = 0;
  double _totalFat = 0;
  final double _calGoal = 2200;
  final double _proteinGoal = 90;
  final double _carbGoal = 250;
  final double _fatGoal = 70;

  // Örnek yemek veritabanı
  final List<Map<String, dynamic>> _foodDB = [
    {'name': 'Yumurta (1 adet)', 'cal': 78, 'protein': 6, 'carb': 0.6, 'fat': 5},
    {'name': 'Ekmek (1 dilim)', 'cal': 80, 'protein': 3, 'carb': 15, 'fat': 1},
    {'name': 'Tavuk Göğsü (100g)', 'cal': 165, 'protein': 31, 'carb': 0, 'fat': 3.6},
    {'name': 'Pirinç Pilavı (1 porsiyon)', 'cal': 206, 'protein': 4, 'carb': 45, 'fat': 0.4},
    {'name': 'Mercimek Çorbası (1 kase)', 'cal': 130, 'protein': 9, 'carb': 20, 'fat': 2},
    {'name': 'Yoğurt (200g)', 'cal': 120, 'protein': 8, 'carb': 9, 'fat': 5},
    {'name': 'Muz (1 adet)', 'cal': 89, 'protein': 1.1, 'carb': 23, 'fat': 0.3},
    {'name': 'Elma (1 adet)', 'cal': 52, 'protein': 0.3, 'carb': 14, 'fat': 0.2},
    {'name': 'Zeytinyağı (1 yemek kaşığı)', 'cal': 119, 'protein': 0, 'carb': 0, 'fat': 14},
    {'name': 'Peynir (30g)', 'cal': 100, 'protein': 6, 'carb': 0.5, 'fat': 8},
    {'name': 'Süt (1 bardak)', 'cal': 150, 'protein': 8, 'carb': 12, 'fat': 8},
    {'name': 'Ceviz (30g)', 'cal': 196, 'protein': 4.6, 'carb': 4, 'fat': 19},
    {'name': 'Salatalık (1 adet)', 'cal': 16, 'protein': 0.7, 'carb': 4, 'fat': 0.1},
    {'name': 'Domates (1 adet)', 'cal': 22, 'protein': 1, 'carb': 5, 'fat': 0.2},
    {'name': 'Kırmızı Et (100g)', 'cal': 250, 'protein': 26, 'carb': 0, 'fat': 15},
  ];

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final saved = prefs.getString('meals_$today');
    if (saved != null) {
      setState(() {
        _meals = List<Map<String, dynamic>>.from(jsonDecode(saved));
        _recalculate();
      });
    }
  }

  Future<void> _saveMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('meals_$today', jsonEncode(_meals));
  }

  void _recalculate() {
    _totalCalories = _meals.fold(0, (s, m) => s + (m['cal'] as num));
    _totalProtein = _meals.fold(0, (s, m) => s + (m['protein'] as num));
    _totalCarbs = _meals.fold(0, (s, m) => s + (m['carb'] as num));
    _totalFat = _meals.fold(0, (s, m) => s + (m['fat'] as num));
  }

  void _addMeal(Map<String, dynamic> food) {
    setState(() {
      _meals.add({...food, 'time': TimeOfDay.now().format(context)});
      _recalculate();
    });
    _saveMeals();
  }

  void _removeMeal(int index) {
    setState(() {
      _meals.removeAt(index);
      _recalculate();
    });
    _saveMeals();
  }

  void _showAddMealDialog() {
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Yemek Ekle', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark,
              )),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Yemek ara...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
                onChanged: (v) => setS(() => search = v.toLowerCase()),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: ListView(
                  children: _foodDB
                      .where((f) => f['name'].toString().toLowerCase().contains(search))
                      .map((f) => ListTile(
                    title: Text(f['name'], style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
                    subtitle: Text('${f['cal']} kcal | P:${f['protein']}g K:${f['carb']}g Y:${f['fat']}g',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMid)),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                      onPressed: () { _addMeal(f); Navigator.pop(ctx); },
                    ),
                  ))
                      .toList(),
                ),
              ), // ListView'i saran SizedBox burada kapandı
              const SizedBox(height: 8), // Bu boşluk artık Column'un bir elemanı
            ],
          ), // Column kapandı
        ), // Padding kapandı
      ), // StatefulBuilder kapandı
    ); // showModalBottomSheet kapandı
  }

  @override
  Widget build(BuildContext context) {
    final calPct = (_totalCalories / _calGoal).clamp(0.0, 1.0);
    final remaining = (_calGoal - _totalCalories).clamp(0, _calGoal);
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Günaydın' : now.hour < 18 ? 'İyi öğleden sonralar' : 'İyi akşamlar';

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppTheme.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(greeting, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    const Text('Seda ✨', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                  const Spacer(),
                  CircleAvatar(backgroundColor: Colors.white24,
                      child: const Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    SizedBox(width: 56, height: 56,
                      child: Stack(alignment: Alignment.center, children: [
                        CircularProgressIndicator(
                          value: calPct, strokeWidth: 5,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                        Text('${(calPct * 100).toInt()}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Bugünkü Kalori', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      Text('${_totalCalories.toInt()} kcal',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('$remaining kcal kaldı', style: const TextStyle(fontSize: 10, color: Colors.white60)),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Makro kartlar
            Row(children: [
              _macroCard('Protein', _totalProtein, _proteinGoal, '🥩', Colors.orange),
              const SizedBox(width: 8),
              _macroCard('Karbonhidrat', _totalCarbs, _carbGoal, '🌾', Colors.blue),
              const SizedBox(width: 8),
              _macroCard('Yağ', _totalFat, _fatGoal, '🫒', Colors.purple),
            ]),
            const SizedBox(height: 16),

            // Öneri kartı
            if (_totalProtein < _proteinGoal * 0.75)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Row(children: [
                  const Text('💡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Protein hedefinin gerisinde kaldın. Yumurta, tavuk veya mercimek ekleyebilirsin.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMid, height: 1.4),
                  )),
                ]),
              ),

            // Öğünler başlık
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Bugünkü Öğünler', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              TextButton.icon(
                onPressed: _showAddMealDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ekle', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
              ),
            ]),
            const SizedBox(height: 8),

            // Öğün listesi
            if (_meals.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: const Center(child: Column(children: [
                  Text('🍽️', style: TextStyle(fontSize: 32)),
                  SizedBox(height: 8),
                  Text('Henüz öğün eklemedin', style: TextStyle(fontSize: 13, color: AppTheme.textMid)),
                  Text('+ Ekle butonuna bas', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
              )
            else
              ...List.generate(_meals.length, (i) {
                final m = _meals[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
                      Text('${m['time']} · P:${m['protein']}g K:${m['carb']}g Y:${m['fat']}g',
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMid)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F5EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${m['cal']} kcal',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMid, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeMeal(i),
                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                  ]),
                );
              }),
          ]),
        )),
      ]),
    );
  }

  Widget _macroCard(String name, double val, double goal, String emoji, Color color) {
    final pct = (val / goal).clamp(0.0, 1.0);
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 10, color: AppTheme.textMid)),
        Text('${val.toInt()}g', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct, minHeight: 4,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text('/ ${goal.toInt()}g', style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ]),
    ));
  }
}