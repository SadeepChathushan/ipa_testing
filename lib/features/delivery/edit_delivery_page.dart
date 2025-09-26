// lib/pages/edit_delivery/EditDeliveryPage.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../services/pdf_export.dart';
import '../../services/localization_service.dart'; // You'll need to create this

class EditDeliveryPage extends StatefulWidget {
  const EditDeliveryPage({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  State<EditDeliveryPage> createState() => _EditDeliveryPageState();
}

class _EditDeliveryPageState extends State<EditDeliveryPage> {
  final _repo = Repository.instance;
  Delivery? _delivery;

  // Reused to find/create groups on Enter.
  List<WoodGroup> _groups = [];

  final _lorryController = TextEditingController();

  // Quick-entry controllers
  final _lenCtl = TextEditingController();
  final _widthCtl = TextEditingController();

  // History (visual only): last 3 tuples (x=thickness, y=length, z=width)
  final List<(double, double, double)> _history = [];

  // Thickness dropdown values (as strings, including mixed fractions)
  static const List<String> _kThicknessOptions = <String>[
    '1',
    '1.5',
    '1/8',
    '1 3/8',
    '2',
  ];
  String _selectedThicknessStr = _kThicknessOptions.first; // default '1'

  // Language state
  String _currentLanguage = 'en'; // Default to English

  @override
  void initState() {
    super.initState();
    _load();
    _loadLanguagePreference();
  }

  @override
  void dispose() {
    _lorryController.dispose();
    _lenCtl.dispose();
    _widthCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final deliveries = await _repo.getDeliveries();
    _delivery = deliveries.firstWhere((d) => d.id == widget.deliveryId);
    _lorryController.text = _delivery!.lorryName;
    _groups = await _repo.getGroups(widget.deliveryId);
    if (mounted) setState(() {});
  }

  Future<void> _loadLanguagePreference() async {
    // Load saved language preference
    final savedLanguage = await LocalizationService.getSavedLanguage();
    setState(() {
      _currentLanguage = savedLanguage;
    });
  }

  Future<void> _saveHeader() async {
    if (_delivery == null) return;
    final name = _lorryController.text.trim();
    await _repo.updateDelivery(id: _delivery!.id, lorryName: name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Saved'))));
  }

  // ---- Localization helper ----
  String _t(String english, [String? sinhala]) {
    if (_currentLanguage == 'si' && sinhala != null) {
      return sinhala;
    }
    return english;
  }

  // ---- Parsing helpers ----
  String _fmt(num n) => (n % 1 == 0) ? n.toInt().toString() : n.toString();

  /// Parses numbers, simple fractions "a/b", and mixed fractions "a b/c".
  double? _parseNumberOrFraction(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // mixed fraction: "a b/c"
    if (s.contains(' ')) {
      final parts = s.split(RegExp(r'\s+'));
      if (parts.length != 2) return null;
      final whole = double.tryParse(parts[0]);
      final frac = _parseSimpleFraction(parts[1]);
      if (whole == null || frac == null) return null;
      return whole + frac;
    }

    // simple fraction: "a/b"
    if (s.contains('/')) {
      return _parseSimpleFraction(s);
    }

    // plain number
    return double.tryParse(s);
  }

  double? _parseSimpleFraction(String s) {
    final p = s.split('/');
    if (p.length != 2) return null;
    final a = double.tryParse(p[0].trim());
    final b = double.tryParse(p[1].trim());
    if (a == null || b == null || b == 0) return null;
    return a / b;
  }

  // ---- Ensure a group for (thickness, length) and save width immediately ----
  Future<String> _ensureGroupId(double t, double l) async {
    final existing = _groups.where((g) => g.thickness == t && g.length == l);
    if (existing.isNotEmpty) return existing.first.id;
    final gid = await _repo.addGroup(deliveryId: widget.deliveryId, thickness: t, length: l);
    _groups = await _repo.getGroups(widget.deliveryId);
    return gid;
  }

  /// ENTER now saves immediately to the DB so nothing is lost when you switch thickness.
  Future<void> _addEntry() async {
  final t = _parseNumberOrFraction(_selectedThicknessStr);
  final l = double.tryParse(_lenCtl.text.trim());
  final w = double.tryParse(_widthCtl.text.trim());

  if (t == null || l == null || w == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('Enter valid numbers for thickness, length, width', 
        'වලංගු ඝනකම, දිග සහ පළල ඇතුලත් කරන්න'))),
    );
    return;
  }

  // Persist instantly
  final gid = await _ensureGroupId(t, l);
  await _repo.addWidths(gid, [w]);

  // Visual last-3 history
  setState(() {
    _history.insert(0, (t, l, w));
    if (_history.length > 3) _history.removeRange(3, _history.length);
    _lenCtl.clear(); // Clear length input
    _widthCtl.clear(); // Clear width input
  });

  // if (!mounted) return;
  // ScaffoldMessenger.of(context).showSnackBar(
  //   SnackBar(content: Text(_t('Saved', 'සුරකින ලදී'))),
  // );
}
  void _removeHistoryAt(int i) {
    setState(() {
      _history.removeAt(i);
    });
  }

  /// Show confirmation dialog before submitting to backend
  Future<void> _showSubmitConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Confirm Submission', 'ඉදිරිපත් කිරීම තහවුරු කරන්න')),
        content: Text(_t('Are you sure you want to submit to backend?', 
          'ඔබට ඇත්තටම බැක්එන්ඩ් වෙත ඉදිරිපත් කිරීමට අවශ්‍යද?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('No', 'නැහැ')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('Yes', 'ඔව්')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitAll();
    }
  }

  Future<void> _submitAll() async {
    if (_history.isEmpty) return;
    // If you still want to push the items in the visual history again, you could
    // re-save them here, but since we already persist on Enter, we just clear.
    setState(() => _history.clear());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('Submitted to backend', 'බැක්එන්ඩ් වෙත ඉදිරිපත් කරන ලදී'))));
  }

  // ---------- PDF actions (ALL OPTIONS) ----------
  Future<String> _generatePdf() async {
    // Everything is already in DB because of instant-save on Enter.
    // Just generate from the repository for ALL thickness/length/width.
    final path = await DeliveryPdfService.instance
        .exportDeliveryPdf(widget.deliveryId, shopHeader: 'Shop Header');
    return path;
  }

  Future<void> _exportPdf() async {
    try {
      final path = await _generatePdf();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('PDF saved (app storage): $path', 
          'PDF ගබඩා කර ඇත (යෙදුම් ගබඩාව): $path'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('PDF export failed: $e', 'PDF නිර්යාතය අසාර්ථක විය: $e'))),
      );
    }
  }

  Future<void> _sharePdf() async {
    try {
      final path = await _generatePdf();
      final bytes = await File(path).readAsBytes();
      await Printing.sharePdf(bytes: bytes, filename: p.basename(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Share failed: $e', 'හුවමාරුව අසාර්ථක විය: $e'))),
      );
    }
  }

  Future<void> _saveToDevice() async {
    try {
      final path = await _generatePdf();
      final bytes = await File(path).readAsBytes();

      final savedUri = await FileSaver.instance.saveFile(
        name: p.basenameWithoutExtension(path), // e.g., delivery_326f1570
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Saved to: $savedUri', 'ගබඩා කළ ස්ථානය: $savedUri'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Save failed: $e', 'ගබඩා කිරීම අසාර්ථක විය: $e'))),
      );
    }
  }

  Future<void> _openPdf() async {
    try {
      final path = await _generatePdf();
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Open failed: $e', 'විවෘත කිරීම අසාර්ථක විය: $e'))),
      );
    }
  }

  void _showPdfMenu(Offset? position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position?.dx ?? MediaQuery.of(context).size.width,
        position?.dy ?? kToolbarHeight,
        0,
        0,
      ),
      items: [
        PopupMenuItem(value: 'generate', child: Text(_t('Generate (app storage)', 'ජනනය කරන්න (යෙදුම් ගබඩාව)'))),
        PopupMenuItem(value: 'share', child: Text(_t('Share PDF', 'PDF හුවමාරු කරන්න'))),
        PopupMenuItem(value: 'save', child: Text(_t('Save to device…', 'උපාංගයේ ගබඩා කරන්න…'))),
        PopupMenuItem(value: 'open', child: Text(_t('Open PDF', 'PDF විවෘත කරන්න'))),
      ],
    );

    switch (selected) {
      case 'generate':
        await _exportPdf();
        break;
      case 'share':
        await _sharePdf();
        break;
      case 'save':
        await _saveToDevice();
        break;
      case 'open':
        await _openPdf();
        break;
    }
  }

  // Language toggle function
  Future<void> _toggleLanguage() async {
    final newLanguage = _currentLanguage == 'en' ? 'si' : 'en';
    await LocalizationService.saveLanguage(newLanguage);
    setState(() {
      _currentLanguage = newLanguage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_delivery == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('Edit Delivery', 'භාරදීම සංස්කරණය කරන්න'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final date = DateFormat('yyyy-MM-dd HH:mm').format(_delivery!.date.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Edit Delivery', 'භාරදීම සංස්කරණය කරන්න')),
        actions: [
          // Language toggle button
          IconButton(
            icon: Icon(_currentLanguage == 'en' ? Icons.language : Icons.translate),
            onPressed: _toggleLanguage,
            tooltip: _t('Change Language', 'භාෂාව වෙනස් කරන්න'),
          ),
          // Overflow menu with ALL options
          PopupMenuButton<String>(
            tooltip: _t('PDF Actions', 'PDF ක්‍රියාමාර්ග'),
            onSelected: (v) async {
              switch (v) {
                case 'generate':
                  await _exportPdf();
                  break;
                case 'share':
                  await _sharePdf();
                  break;
                case 'save':
                  await _saveToDevice();
                  break;
                case 'open':
                  await _openPdf();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'generate', child: Text(_t('Generate (app storage)', 'ජනනය කරන්න (යෙදුම් ගබඩාව)'))),
              PopupMenuItem(value: 'share', child: Text(_t('Share PDF', 'PDF හුවමාරු කරන්න'))),
              PopupMenuItem(value: 'save', child: Text(_t('Save to device…', 'උපාංගයේ ගබඩා කරන්න…'))),
              PopupMenuItem(value: 'open', child: Text(_t('Open PDF', 'PDF විවෘත කරන්න'))),
            ],
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---- Compact header ----
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lorryController,
                      decoration: InputDecoration(
                        labelText: _t('Lorry name', 'ලොරි නම'),
                        isDense: true
                      ),
                      onSubmitted: (_) => _saveHeader(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_t('Date', 'දිනය')}: $date', style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _t('Save', 'සුරකින්න'),
                    onPressed: _saveHeader,
                    icon: const Icon(Icons.save),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ---- Main quick-entry ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // History box (visual last 3, the data is already saved)
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _history.isEmpty
                          ? Center(child: Text(_t('History last 3 (empty)', 'අවසන් 3 (හිස්)')))
                          : ListView.separated(
                              itemCount: _history.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final e = _history[i];
                                return ListTile(
                                  dense: true,
                                  title: Text('x=${_fmt(e.$1)}   y=${_fmt(e.$2)}   z=${_fmt(e.$3)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => _removeHistoryAt(i),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // THICKNESS dropdown (rarely changes)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        value: _selectedThicknessStr,
                        decoration: InputDecoration(
                          labelText: _t('thickness (trenches)', 'ඝනකම (ට්‍රෙන්ච්)')
                        ),
                        items: _kThicknessOptions
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedThicknessStr = v);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // LENGTH + WIDTH (change frequently)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lenCtl,
                          decoration: InputDecoration(
                            labelText: _t('length (ft)', 'දිග (අඩි)')
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          // Allow mobile number pad enter key
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _widthCtl,
                          decoration: InputDecoration(
                            labelText: _t('width (trenches)', 'පළල (ට්‍රෙන්ච්)')
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          // Allow mobile number pad enter key to submit
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addEntry(),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Enter + Submit + PDF menu button
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => _addEntry(),
                          child: Text(_t('Enter (save)', 'ඇතුලත් කරන්න (සුරකින්න)')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _history.isEmpty ? null : _showSubmitConfirmation,
                          icon: const Icon(Icons.cloud_upload),
                          label: Text(_t('Submit', 'ඉදිරිපත් කරන්න')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Small PDF menu near the buttons
                      InkResponse(
                        onTapDown: (d) => _showPdfMenu(d.globalPosition),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(Icons.picture_as_pdf),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}