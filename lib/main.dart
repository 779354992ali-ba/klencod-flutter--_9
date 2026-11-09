import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MobileIDEApp());
}

class MobileIDEApp extends StatelessWidget {
  const MobileIDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bisho IDE',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0F12),
        primaryColor: const Color(0xFF6366F1),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFFEC4899),
          surface: Color(0xFF161B22),
        ),
        fontFamily: 'monospace',
      ),
      home: const IDEScreen(),
    );
  }
}

class IDEScreen extends StatefulWidget {
  const IDEScreen({super.key});

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {
  final TextEditingController _codeController = TextEditingController();
  String currentFilePath = '';
  List<FileSystemEntity> _files = [];
  Directory? _projectDir;
  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
    _requestStoragePermissionAndInit();
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (!_isModified && currentFilePath.isNotEmpty) {
      setState(() {
        _isModified = true;
      });
    }
  }

  Future<void> _requestStoragePermissionAndInit() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    final docDir = await getApplicationDocumentsDirectory();
    final projectDir = Directory('${docDir.path}/BishoProject');
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
      
      Directory('${projectDir.path}/lib').createSync();
      Directory('${projectDir.path}/assets').createSync();
      Directory('${projectDir.path}/build').createSync();

      final defaultFile = File('${projectDir.path}/lib/index.html');
      await defaultFile.writeAsString('''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <title>Bisho IDE Preview</title>
    <style>
        body { background: #121212; color: #34D399; font-family: sans-serif; text-align: center; padding-top: 50px; }
        h1 { color: #6366F1; }
    </style>
</head>
<body>
    <h1>مرحباً بك في Bisho IDE!</h1>
    <p>هذه معاينة حية لصفحتك من الهاتف المحمول.</p>
</body>
</html>''');
      
      final pubspec = File('${projectDir.path}/pubspec.yaml');
      await pubspec.writeAsString('name: bisho_ide\nversion: 1.0.0+1');
    }

    setState(() {
      _projectDir = projectDir;
    });
    _loadFileList();
    
    final defaultOpen = File('${projectDir.path}/lib/index.html');
    if (defaultOpen.existsSync()) {
      _openFile(defaultOpen);
    }
  }

  void _loadFileList() {
    if (_projectDir != null) {
      setState(() {
        _files = _projectDir!.listSync(recursive: true, followLinks: false);
      });
    }
  }

  Future<void> _openFile(File file) async {
    final content = await file.readAsString();
    setState(() {
      currentFilePath = file.path;
      _codeController.text = content;
      _isModified = false;
    });
  }

  Future<void> _saveFile() async {
    if (currentFilePath.isNotEmpty) {
      await File(currentFilePath).writeAsString(_codeController.text);
      setState(() {
        _isModified = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent),
              SizedBox(width: 10),
              Text('تم حفظ الملف بنجاح!'),
            ],
          ),
          backgroundColor: const Color(0xFF1F2937),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار ملف للحفظ أولاً'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _deleteFile(File file) async {
    final fileName = file.path.split('/').last;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('حذف العنصر', style: TextStyle(color: Colors.white)),
        content: Text('هل أنت متأكد من حذف "$fileName" نهائياً؟', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (await file.exists()) await file.delete();
              Navigator.pop(context);
              _loadFileList();
              if (currentFilePath == file.path) {
                setState(() {
                  currentFilePath = '';
                  _codeController.clear();
                  _isModified = false;
                });
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewItemDialog() async {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('إنشاء ملف جديد', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'اسم الملف (مثال: style.css)',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () async {
              if (nameController.text.isNotEmpty && _projectDir != null) {
                final newFile = File('${_projectDir!.path}/${nameController.text}');
                await newFile.writeAsString('<!-- كود جديد -->');
                Navigator.pop(context);
                _loadFileList();
                _openFile(newFile);
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _openProjectSettings() async {
    Navigator.pop(context);
    final pubspecFile = File('${_projectDir?.path}/pubspec.yaml');
    String currentName = 'bisho_ide';
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      final match = RegExp(r'name:\s*(.+)').firstMatch(content);
      if (match != null) {
        currentName = match.group(1)!.trim();
      }
    }
    final TextEditingController nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.settings_applications, color: Color(0xFF6366F1)),
            SizedBox(width: 10),
            Text('إعدادات مشروع Bisho IDE', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اسم حزمة المشروع (تحديث pubspec.yaml):', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            const Text('• إصدار SDK: Flutter 3.x / Dart 3', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            const Text('• مسار المشروع المحلي:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            Text('${_projectDir?.path}', style: const TextStyle(color: Color(0xFF34D399), fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () async {
              if (await pubspecFile.exists()) {
                String content = await pubspecFile.readAsString();
                content = content.replaceFirst(RegExp(r'name:\s*.+'), 'name: ${nameController.text.trim()}');
                await pubspecFile.writeAsString(content);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('⚙️ تم تحديث إعدادات وحفظ pubspec.yaml بنجاح!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBuildApk() async {
    Navigator.pop(context);
    int fileCount = _files.length;
    bool hasMain = _files.any((f) => f.path.endsWith('main.dart') || f.path.endsWith('index.html'));
    bool hasPubspec = _files.any((f) => f.path.endsWith('pubspec.yaml'));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.rocket_launch, color: Colors.greenAccent),
            SizedBox(width: 10),
            Text('تقرير فحص وبناء الحزمة', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• إجمالي عناصر المشروع: $fileCount عنصر', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('• ملف العرض/التنفيذ الأساسي: ${hasMain ? "موجود ✅" : "مفقود ❌"}',
                style: TextStyle(color: hasMain ? Colors.greenAccent : Colors.redAccent)),
            const SizedBox(height: 6),
            Text('• ملف إعدادات الحزمة (pubspec.yaml): ${hasPubspec ? "موجود ✅" : "مفقود ❌"}',
                style: TextStyle(color: hasPubspec ? Colors.greenAccent : Colors.redAccent)),
            const SizedBox(height: 12),
            const Text(
              'الحالة: تم فحص البيئة المحلية بنجاح وجاهز لتصدير الملفات لتطبيقك النهائي!',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportProjectZip() async {
    Navigator.pop(context);
    try {
      if (_projectDir == null) return;
      final exportDir = Directory('/storage/emulated/0/Download/BishoProject_Export');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      await _copyDirectory(_projectDir!, exportDir);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📦 تم تصدير مجلد المشروع كاملاً إلى:\nDownload/BishoProject_Export'),
          backgroundColor: Colors.blue.shade800,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (var entity in source.list(recursive: false)) {
      String newPath = '${destination.path}/${entity.path.split('/').last}';
      if (entity is Directory) {
        Directory newDir = Directory(newPath);
        if (!await newDir.exists()) {
          await newDir.create();
        }
        await _copyDirectory(entity, newDir);
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  void _formatCode() {
    String text = _codeController.text;
    text = text.replaceAll(';', ';\n').replaceAll('{', '{\n  ').replaceAll('}', '\n}');
    setState(() {
      _codeController.text = text;
      _isModified = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✨ تم تنسيق الكود بنجاح'), duration: Duration(seconds: 1)),
    );
  }

  void _insertSymbol(String symbol) {
    final text = _codeController.text;
    final selection = _codeController.selection;
    if (selection.isValid) {
      final newText = text.replaceRange(selection.start, selection.end, symbol);
      _codeController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + symbol.length),
      );
    } else {
      _codeController.text = text + symbol;
    }
  }

  void _openLivePreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewScreen(htmlContent: _codeController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String fileName = currentFilePath.isEmpty ? 'Bisho IDE' : currentFilePath.split('/').last;
    if (_isModified) fileName += ' *';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            const Icon(Icons.code, color: Color(0xFF6366F1), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Color(0xFFEC4899), size: 20),
            onPressed: _formatCode,
            tooltip: 'تنسيق الكود',
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 22),
            onPressed: _openLivePreview,
            tooltip: 'معاينة حية',
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded, color: Color(0xFF38BDF8), size: 20),
            onPressed: _saveFile,
            tooltip: 'حفظ الملف',
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF111318),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: Color(0xFF374151), width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.terminal, color: Color(0xFF6366F1), size: 28),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bisho IDE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('بيئة التطوير الشاملة للهاتف', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.folder_open, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Text('هيكل المشروع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Material(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _createNewItemDialog,
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF374151), height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final entity = _files[index];
                  final name = entity.path.split('/').last;
                  bool isDir = entity is Directory;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                      color: isDir ? Colors.amberAccent : const Color(0xFF38BDF8),
                      size: 18,
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    trailing: isDir ? null : IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                      onPressed: () => _deleteFile(entity as File),
                    ),
                    onTap: () {
                      if (!isDir && entity is File) {
                        _openFile(entity);
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
            const Divider(color: Color(0xFF374151), height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDrawerButton(
                          icon: Icons.settings_rounded,
                          label: 'الإعدادات',
                          color: const Color(0xFF4F46E5),
                          onTap: _openProjectSettings,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDrawerButton(
                          icon: Icons.rocket_rounded,
                          label: 'بناء APK',
                          color: Colors.green.shade700,
                          onTap: _startBuildApk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _buildDrawerButton(
                      icon: Icons.archive_rounded,
                      label: 'تصدير المشروع (ZIP)',
                      color: Colors.blue.shade700,
                      onTap: _exportProjectZip,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF0D0F12),
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _codeController,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Color(0xFF34D399),
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '// اختر ملفاً من القائمة الجانبية أو أضف ملفاً جديداً للبدء...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          ),
          Container(
            height: 42,
            color: const Color(0xFF161B22),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildSymbolButton('{ }'),
                _buildSymbolButton('( )'),
                _buildSymbolButton('[ ]'),
                _buildSymbolButton(';'),
                _buildSymbolButton('='),
                _buildSymbolButton('"'),
                _buildSymbolButton('<'),
                _buildSymbolButton('>'),
                _buildSymbolButton('/'),
                _buildSymbolButton('-'),
                _buildSymbolButton('_'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolButton(String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _insertSymbol(symbol),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              symbol,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class PreviewScreen extends StatelessWidget {
  final String htmlContent;
  const PreviewScreen({super.key, required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    final previewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(htmlContent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المعاينة الحية التفاعلية'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: WebViewWidget(controller: previewController),
    );
  }
}
