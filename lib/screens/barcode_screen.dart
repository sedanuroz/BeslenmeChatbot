// lib/screens/barcode_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme.dart';
import '../services/api_service.dart';

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});
  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  MobileScannerController _scannerController = MobileScannerController();
  bool _scanning = true;
  bool _loading = false;
  Map<String, dynamic>? _product;
  String? _aiAnalysis;
  String? _error;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('barcode_history');
    if (saved != null) {
      setState(() {
        _history = List<Map<String, dynamic>>.from(jsonDecode(saved));
      });
    }
  }

  Future<void> _saveToHistory(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final entry = {
      ...product,
      'scannedAt': '${now.day}.${now.month}.${now.year} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    };

    // Aynı ürün zaten varsa güncelle
    _history.removeWhere((h) => h['name'] == product['name']);
    _history.insert(0, entry);

    // Max 20 geçmiş tut
    if (_history.length > 20) _history = _history.sublist(0, 20);

    await prefs.setString('barcode_history', jsonEncode(_history));
    setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('barcode_history');
    setState(() => _history = []);
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (!_scanning) return;
    final barcode = capture.barcodes.first;
    final code = barcode.rawValue;
    if (code == null) return;

    setState(() {
      _scanning = false;
      _loading = true;
      _product = null;
      _aiAnalysis = null;
      _error = null;
    });

    await _scannerController.stop();
    await _fetchProduct(code);
  }

  Future<void> _fetchProduct(String barcode) async {
    try {
      final res = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 1) {
          final product = data['product'];
          final nutriments = product['nutriments'] ?? {};

          final p = {
            'name': product['product_name'] ?? 'Bilinmiyor',
            'brand': product['brands'] ?? '',
            'calories': nutriments['energy-kcal_100g']?.toStringAsFixed(0) ?? '?',
            'protein': nutriments['proteins_100g']?.toStringAsFixed(1) ?? '?',
            'carbs': nutriments['carbohydrates_100g']?.toStringAsFixed(1) ?? '?',
            'fat': nutriments['fat_100g']?.toStringAsFixed(1) ?? '?',
            'sugar': nutriments['sugars_100g']?.toStringAsFixed(1) ?? '?',
            'fiber': nutriments['fiber_100g']?.toStringAsFixed(1) ?? '?',
            'salt': nutriments['salt_100g']?.toStringAsFixed(1) ?? '?',
            'image': product['image_front_url'] ?? '',
            'ingredients': product['ingredients_text'] ?? '',
          };

          setState(() {
            _product = p;
            _loading = false;
          });

          await _saveToHistory(p);
          await _getAiAnalysis();
        } else {
          setState(() {
            _error = 'Ürün bulunamadı. Farklı bir barkod deneyin.';
            _loading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Hata oluştu: $e';
        _loading = false;
      });
    }
  }

  Future<void> _getAiAnalysis() async {
    if (_product == null) return;
    final p = _product!;
    final question =
        '${p['name']} ürününün besin değerleri: '
        '100g başına kalori: ${p['calories']} kcal, '
        'protein: ${p['protein']}g, karbonhidrat: ${p['carbs']}g, '
        'yağ: ${p['fat']}g, şeker: ${p['sugar']}g. '
        'Bu ürün sağlıklı bir diyet için uygun mu? Kısa ve net değerlendir.';

    final answer = await ApiService.chat(question);
    setState(() => _aiAnalysis = answer);
  }

  void _showHistoryDetail(Map<String, dynamic> item) {
    setState(() {
      _product = item;
      _aiAnalysis = null;
      _scanning = false;
      _loading = false;
      _error = null;
    });
    _getAiAnalysis();
  }

  void _resetScanner() {
    setState(() {
      _scanning = true;
      _product = null;
      _aiAnalysis = null;
      _error = null;
    });
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod Tarayıcı',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (!_scanning)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              onPressed: _resetScanner,
              tooltip: 'Yeniden Tara',
            ),
        ],
      ),
      body: _scanning
          ? _buildScannerWithHistory()
          : _loading
          ? _buildLoading()
          : _error != null
          ? _buildError()
          : _buildResult(),
    );
  }

  // Tarayıcı + geçmiş birlikte
  Widget _buildScannerWithHistory() {
    return Column(children: [
      // Kamera alanı
      SizedBox(
        height: 320,
        child: Stack(children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
          ),
          Container(color: Colors.black.withOpacity(0.45)),
          Center(
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SizedBox(
                width: 220, height: 220,
                child: CustomPaint(painter: _CornerPainter()),
              ),
            ]),
          ),
          const Positioned(
            bottom: 16, left: 0, right: 0,
            child: Column(children: [
              Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
              SizedBox(height: 6),
              Text('Barkodu çerçeve içine alın',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center),
            ]),
          ),
        ]),
      ),

      // Geçmiş listesi
      Expanded(
        child: _history.isEmpty
            ? const Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Henüz tarama geçmişi yok',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            Text('İlk ürünü tara!',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ))
            : Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Son Taramalar (${_history.length})',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppTheme.textDark)),
                TextButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Geçmişi Temizle'),
                      content: const Text('Tüm tarama geçmişi silinecek. Emin misin?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx),
                            child: const Text('İptal')),
                        TextButton(
                          onPressed: () { _clearHistory(); Navigator.pop(ctx); },
                          child: const Text('Temizle', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.grey),
                  label: const Text('Temizle',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _history.length,
              itemBuilder: (ctx, i) {
                final item = _history[i];
                return GestureDetector(
                  onTap: () => _showHistoryDetail(item),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: Row(children: [
                      // Ürün resmi veya ikon
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item['image'] != null && item['image'].isNotEmpty
                            ? Image.network(item['image'],
                            width: 44, height: 44, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              width: 44, height: 44,
                              color: const Color(0xFFE1F5EE),
                              child: const Icon(Icons.fastfood,
                                  color: AppTheme.primary, size: 22),
                            ))
                            : Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1F5EE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood,
                              color: AppTheme.primary, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'],
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w500, color: AppTheme.textDark),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (item['brand'] != null && item['brand'].isNotEmpty)
                            Text(item['brand'],
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE1F5EE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${item['calories']} kcal',
                                  style: const TextStyle(fontSize: 10,
                                      color: AppTheme.primary, fontWeight: FontWeight.w500)),
                            ),
                            const SizedBox(width: 6),
                            Text('P:${item['protein']}g K:${item['carbs']}g Y:${item['fat']}g',
                                style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ]),
                        ],
                      )),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(item['scannedAt'] ?? '',
                              style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          const SizedBox(height: 4),
                          const Icon(Icons.chevron_right,
                              color: AppTheme.border, size: 18),
                        ],
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildLoading() {
    return const Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: AppTheme.primary),
        SizedBox(height: 16),
        Text('Ürün analiz ediliyor...',
            style: TextStyle(color: AppTheme.textMid, fontSize: 14)),
        SizedBox(height: 4),
        Text('OpenFoodFacts\'ten veri çekiliyor',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ));
  }

  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textDark)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _resetScanner,
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar Dene'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    ));
  }

  Widget _buildResult() {
    if (_product == null) return const SizedBox();
    final p = _product!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ürün başlık
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: p['image'] != null && p['image'].isNotEmpty
                  ? Image.network(p['image'],
                  width: 70, height: 70, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 70, height: 70,
                    color: const Color(0xFFE1F5EE),
                    child: const Icon(Icons.fastfood, color: AppTheme.primary, size: 32),
                  ))
                  : Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fastfood, color: AppTheme.primary, size: 32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['name'], style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              if (p['brand'] != null && p['brand'].isNotEmpty)
                Text(p['brand'], style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5EE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${p['calories']} kcal / 100g',
                    style: const TextStyle(fontSize: 11,
                        color: AppTheme.primary, fontWeight: FontWeight.w500)),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 12),

        // Besin değerleri
        const Text('Besin Değerleri (100g)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3, childAspectRatio: 1.4,
          crossAxisSpacing: 8, mainAxisSpacing: 8,
          children: [
            _nutriCard('Protein', '${p['protein']}g', '🥩', Colors.orange),
            _nutriCard('Karbonhidrat', '${p['carbs']}g', '🌾', Colors.blue),
            _nutriCard('Yağ', '${p['fat']}g', '🫒', Colors.purple),
            _nutriCard('Şeker', '${p['sugar']}g', '🍬', Colors.pink),
            _nutriCard('Lif', '${p['fiber']}g', '🌿', AppTheme.primary),
            _nutriCard('Tuz', '${p['salt']}g', '🧂', Colors.grey),
          ],
        ),
        const SizedBox(height: 12),

        // AI analizi
        const Text('🤖 AI Analizi',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: _aiAnalysis == null
              ? const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2)))
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🥗', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(_aiAnalysis!,
                style: const TextStyle(fontSize: 12,
                    color: AppTheme.textDark, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 16),

        // Butonlar
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _resetScanner,
            icon: const Icon(Icons.qr_code_scanner, size: 16),
            label: const Text('Yeni Tara'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => setState(() {
              _scanning = true;
              _product = null;
              _aiAnalysis = null;
            }),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('Geçmiş'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _nutriCard(String label, String value, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ]),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    canvas.drawLine(Offset.zero, const Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, len), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}