import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const PvAbnahmeApp());
}

class PvAbnahmeApp extends StatelessWidget {
  const PvAbnahmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF007A3D);

    return MaterialApp(
      title: 'PV-Abnahmeprotokoll',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: green,
        scaffoldBackgroundColor: const Color(0xFFF4F7F4),
        appBarTheme: const AppBarTheme(
          backgroundColor: green,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const PvAbnahmePage(),
    );
  }
}

class PvAbnahmePage extends StatefulWidget {
  const PvAbnahmePage({super.key});

  @override
  State<PvAbnahmePage> createState() => _PvAbnahmePageState();
}

class _PvAbnahmePageState extends State<PvAbnahmePage> {
  static const Color green = Color(0xFF007A3D);

  final stt.SpeechToText speech = stt.SpeechToText();
  final ImagePicker imagePicker = ImagePicker();
  final List<File> visualInspectionPhotos = [];

  bool speechReady = false;
  bool isListening = false;
  TextEditingController? activeSpeechController;

  String? pdfPath;

  final customerController = TextEditingController();
  final objectController = TextEditingController();
  final plantNumberController = TextEditingController();
  final moduleFieldController = TextEditingController();
  final inverterController = TextEditingController();
  final moduleManufacturerController = TextEditingController();
  final moduleTypeController = TextEditingController();
  final moduleCountController = TextEditingController();
  final generatorPowerController = TextEditingController();
  final technicianController = TextEditingController();
  final dateController = TextEditingController();

  final visualNoteController = TextEditingController();
  final functionNoteController = TextEditingController();
  final measurementNoteController = TextEditingController();
  final generalNoteController = TextEditingController();
  final resultNoteController = TextEditingController();

  final SignatureController technicianSignaturePad =
  SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  final SignatureController customerSignaturePad =
  SignatureController(penStrokeWidth: 3, penColor: Colors.black);

  bool modulesOk = false;
  bool cablesOk = false;
  bool plugsOk = false;
  bool labelingOk = false;
  bool dcSwitchOk = false;
  bool groundingOk = false;
  bool protectionOk = false;

  bool inverterFunctionOk = false;
  bool dcDisconnectOk = false;
  bool acDisconnectOk = false;
  bool monitoringOk = false;
  bool shutdownOk = false;
  bool warningSignsOk = false;

  bool testPassed = false;

  late final List<TextEditingController> vocControllers;
  late final List<TextEditingController> iscControllers;
  late final List<TextEditingController> risoControllers;
  late final List<bool> polarityOk;
  late final List<bool> stringOk;

  @override
  void initState() {
    super.initState();

    vocControllers = List.generate(24, (_) => TextEditingController());
    iscControllers = List.generate(24, (_) => TextEditingController());
    risoControllers = List.generate(24, (_) => TextEditingController());
    polarityOk = List.generate(24, (_) => false);
    stringOk = List.generate(24, (_) => false);

    setToday();
    initSpeech();
  }

  Future<void> initSpeech() async {
    await Permission.microphone.request();

    final available = await speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() {
            isListening = false;
            activeSpeechController = null;
          });
        }
      },
      onError: (_) {
        setState(() {
          isListening = false;
          activeSpeechController = null;
        });
      },
    );

    setState(() {
      speechReady = available;
    });
  }

  Future<void> startSpeechInput(TextEditingController controller) async {
    if (!speechReady) {
      await initSpeech();
    }

    if (!speechReady) {
      showMessage('Spracheingabe nicht verfügbar. Bitte Mikrofonberechtigung prüfen.');
      return;
    }

    setState(() {
      isListening = true;
      activeSpeechController = controller;
    });

    await speech.listen(
      localeId: 'de_DE',
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      onResult: (result) {
        setState(() {
          controller.text = cleanSpeechText(result.recognizedWords);
        });
      },
    );
  }

  Future<void> stopSpeechInput() async {
    await speech.stop();

    setState(() {
      isListening = false;
      activeSpeechController = null;
    });
  }

  String cleanSpeechText(String text) {
    return text
        .replaceAll(' Komma ', ',')
        .replaceAll(' komma ', ',')
        .replaceAll(' Punkt ', ',')
        .replaceAll(' punkt ', ',')
        .trim();
  }

  void setToday() {
    final now = DateTime.now();
    dateController.text =
    '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }

  @override
  void dispose() {
    customerController.dispose();
    objectController.dispose();
    plantNumberController.dispose();
    moduleFieldController.dispose();
    inverterController.dispose();
    moduleManufacturerController.dispose();
    moduleTypeController.dispose();
    moduleCountController.dispose();
    generatorPowerController.dispose();
    technicianController.dispose();
    dateController.dispose();

    visualNoteController.dispose();
    functionNoteController.dispose();
    measurementNoteController.dispose();
    generalNoteController.dispose();
    resultNoteController.dispose();

    technicianSignaturePad.dispose();
    customerSignaturePad.dispose();

    for (final c in vocControllers) {
      c.dispose();
    }
    for (final c in iscControllers) {
      c.dispose();
    }
    for (final c in risoControllers) {
      c.dispose();
    }

    speech.stop();
    super.dispose();
  }

  String valueOf(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? '-' : value;
  }

  int completedVisualChecks() {
    return [
      modulesOk,
      cablesOk,
      plugsOk,
      labelingOk,
      dcSwitchOk,
      groundingOk,
      protectionOk,
      warningSignsOk,
    ].where((v) => v).length;
  }

  int completedFunctionChecks() {
    return [
      inverterFunctionOk,
      dcDisconnectOk,
      acDisconnectOk,
      monitoringOk,
      shutdownOk,
    ].where((v) => v).length;
  }

  int completedMeasurements() {
    int count = 0;

    for (var i = 0; i < 24; i++) {
      if (vocControllers[i].text.trim().isNotEmpty) count++;
      if (iscControllers[i].text.trim().isNotEmpty) count++;
      if (risoControllers[i].text.trim().isNotEmpty) count++;
      if (polarityOk[i]) count++;
      if (stringOk[i]) count++;
    }

    return count;
  }

  Future<void> takeVisualInspectionPhoto() async {
    final cameraStatus = await Permission.camera.request();

    if (!cameraStatus.isGranted) {
      showMessage('Kameraberechtigung fehlt. Bitte in den Android-Einstellungen erlauben.');
      return;
    }

    final XFile? photo = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1600,
    );

    if (photo == null) {
      return;
    }

    setState(() {
      visualInspectionPhotos.add(File(photo.path));
    });
  }

  void removeVisualInspectionPhoto(int index) {
    setState(() {
      visualInspectionPhotos.removeAt(index);
    });
  }

  Future<void> createPdf() async {
    final pdf = pw.Document();

    final Uint8List? technicianSignatureBytes =
    await technicianSignaturePad.toPngBytes();
    final Uint8List? customerSignatureBytes =
    await customerSignaturePad.toPngBytes();

    final visualInspectionPhotoBytes = <Uint8List>[];
    for (final photo in visualInspectionPhotos) {
      if (await photo.exists()) {
        visualInspectionPhotoBytes.add(await photo.readAsBytes());
      }
    }

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'PV-Abnahmeprotokoll',
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Sichtprüfung · Erproben · Messen · Unterschrift'),
          pw.Text('PV-Anlagenprüfung nach DIN EN 62446'),
          pw.SizedBox(height: 20),

          pdfSection('Kunde', valueOf(customerController)),
          pdfSection('Objekt / Standort', valueOf(objectController)),
          pdfSection('Anlagennummer', valueOf(plantNumberController)),
          pdfSection('Modulfeld', valueOf(moduleFieldController)),
          pdfSection('Wechselrichter', valueOf(inverterController)),
          pdfSection('Modulhersteller', valueOf(moduleManufacturerController)),
          pdfSection('Modultyp', valueOf(moduleTypeController)),
          pdfSection('Anzahl Module', valueOf(moduleCountController)),
          pdfSection('Generatorleistung', valueOf(generatorPowerController)),
          pdfSection('Monteur', valueOf(technicianController)),
          pdfSection('Datum', valueOf(dateController)),

          pw.SizedBox(height: 18),
          pw.Text('1. Sichtprüfung',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pdfCheck('Module sichtbar unbeschädigt', modulesOk),
          pdfCheck('Leitungen geprüft', cablesOk),
          pdfCheck('Steckverbinder geprüft', plugsOk),
          pdfCheck('Kennzeichnung vorhanden', labelingOk),
          pdfCheck('DC-Trennstelle / Schaltgerät vorhanden', dcSwitchOk),
          pdfCheck('Erdung / Potentialausgleich geprüft', groundingOk),
          pdfCheck('Schutzmaßnahmen geprüft', protectionOk),
          pdfCheck('Warnhinweise / Beschilderung geprüft', warningSignsOk),
          pdfSection('Bemerkung Sichtprüfung', valueOf(visualNoteController)),
          if (visualInspectionPhotoBytes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Fotos Sichtprüfung',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: visualInspectionPhotoBytes.map((bytes) {
                return pw.Container(
                  width: 160,
                  height: 120,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(bytes),
                    fit: pw.BoxFit.cover,
                  ),
                );
              }).toList(),
            ),
          ],

          pw.SizedBox(height: 18),
          pw.Text('2. Erproben / Funktionsprüfung',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pdfCheck('Wechselrichter Funktion geprüft', inverterFunctionOk),
          pdfCheck('DC-Trennschalter geprüft', dcDisconnectOk),
          pdfCheck('AC-Trennstelle geprüft', acDisconnectOk),
          pdfCheck('Monitoring / Kommunikation geprüft', monitoringOk),
          pdfCheck('Abschaltung / Schaltfunktion geprüft', shutdownOk),
          pdfSection('Bemerkung Erproben', valueOf(functionNoteController)),

          pw.SizedBox(height: 18),
          pw.Text('3. Messungen',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          measurementTable(),
          pw.SizedBox(height: 12),
          pdfSection('Bemerkung Messung', valueOf(measurementNoteController)),

          pw.SizedBox(height: 18),
          pw.Text('4. Prüfergebnis',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pdfSection('Ergebnis',
              testPassed ? 'PV-Anlage bestanden' : 'PV-Anlage nicht bestanden'),
          pdfSection('Bemerkung Ergebnis', valueOf(resultNoteController)),
          pdfSection('Allgemeine Bemerkung', valueOf(generalNoteController)),

          pw.SizedBox(height: 18),
          pw.Text('5. Unterschriften',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: signaturePdfBox(
                  title: 'Unterschrift Monteur',
                  bytes: technicianSignatureBytes,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: signaturePdfBox(
                  title: 'Unterschrift Kunde',
                  bytes: customerSignatureBytes,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),
          pw.Text(
            'Hinweis: Die Ergebnisse und Unterschriften wurden digital erfasst und sind vor Weitergabe fachlich zu prüfen.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/PV_Abnahmeprotokoll_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    await file.writeAsBytes(await pdf.save());

    setState(() {
      pdfPath = file.path;
    });

    showMessage('PDF-Abnahmeprotokoll wurde erstellt.');
  }

  pw.Widget pdfSection(String title, String content) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 155,
            child: pw.Text(title,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(content)),
        ],
      ),
    );
  }

  pw.Widget pdfCheck(String title, bool checked) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 28, child: pw.Text(checked ? 'OK' : '-')),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(title)),
        ],
      ),
    );
  }

  pw.Widget measurementTable() {
    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          tableHeader('String'),
          tableHeader('Voc [V DC]'),
          tableHeader('Isc [A]'),
          tableHeader('Riso [MOhm]'),
          tableHeader('Polarität'),
          tableHeader('Ergebnis'),
        ],
      ),
    ];

    for (var i = 0; i < 24; i++) {
      rows.add(
        pw.TableRow(
          children: [
            tableCell((i + 1).toString()),
            tableCell(valueOf(vocControllers[i])),
            tableCell(valueOf(iscControllers[i])),
            tableCell(valueOf(risoControllers[i])),
            tableCell(polarityOk[i] ? 'OK' : '-'),
            tableCell(stringOk[i] ? 'Bestanden' : '-'),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(),
        2: const pw.FlexColumnWidth(),
        3: const pw.FlexColumnWidth(),
        4: const pw.FixedColumnWidth(55),
        5: const pw.FixedColumnWidth(70),
      },
      children: rows,
    );
  }

  pw.Widget tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text),
    );
  }

  pw.Widget signaturePdfBox({
    required String title,
    required Uint8List? bytes,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 90,
          width: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: bytes == null
              ? pw.Center(child: pw.Text('Keine Unterschrift'))
              : pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
        ),
      ],
    );
  }

  Future<void> openPdf() async {
    if (pdfPath == null) {
      showMessage('Bitte zuerst Abnahmeprotokoll erstellen.');
      return;
    }

    await OpenFilex.open(pdfPath!);
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void resetAll() {
    setState(() {
      pdfPath = null;

      modulesOk = false;
      cablesOk = false;
      plugsOk = false;
      labelingOk = false;
      dcSwitchOk = false;
      groundingOk = false;
      protectionOk = false;

      inverterFunctionOk = false;
      dcDisconnectOk = false;
      acDisconnectOk = false;
      monitoringOk = false;
      shutdownOk = false;
      warningSignsOk = false;

      testPassed = false;

      for (var i = 0; i < 24; i++) {
        vocControllers[i].clear();
        iscControllers[i].clear();
        risoControllers[i].clear();
        polarityOk[i] = false;
        stringOk[i] = false;
      }

      technicianSignaturePad.clear();
      customerSignaturePad.clear();
      visualInspectionPhotos.clear();
    });

    customerController.clear();
    objectController.clear();
    plantNumberController.clear();
    moduleFieldController.clear();
    inverterController.clear();
    moduleManufacturerController.clear();
    moduleTypeController.clear();
    moduleCountController.clear();
    generatorPowerController.clear();
    technicianController.clear();
    visualNoteController.clear();
    functionNoteController.clear();
    measurementNoteController.clear();
    generalNoteController.clear();
    resultNoteController.clear();

    setToday();
  }

  Widget header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PV-Abnahmeprotokoll',
              style: TextStyle(
                  color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Sichtprüfung · Erproben · Messen',
              style: TextStyle(color: Colors.white, fontSize: 18)),
          SizedBox(height: 6),
          Text('Dokumentation nach DIN EN 62446',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget inputField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    final active = activeSpeechController == controller && isListening;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: active ? stopSpeechInput : () => startSpeechInput(controller),
            icon: Icon(active ? Icons.stop : Icons.mic),
            tooltip: 'Spracheingabe',
          ),
        ],
      ),
    );
  }

  Widget checkTile({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: green,
    );
  }

  Widget masterDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Anlagendaten',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            inputField('Kunde', customerController),
            inputField('Objekt / Standort', objectController),
            inputField('Anlagennummer', plantNumberController),
            inputField('Modulfeld', moduleFieldController),
            inputField('Wechselrichter', inverterController),
            inputField('Modulhersteller', moduleManufacturerController),
            inputField('Modultyp', moduleTypeController),
            inputField('Anzahl Module', moduleCountController),
            inputField('Generatorleistung (kWp)', generatorPowerController),
            inputField('Monteur', technicianController),
            inputField('Datum', dateController),
          ],
        ),
      ),
    );
  }

  Widget progressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Prüfübersicht',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Sichtprüfung: ${completedVisualChecks()} von 8 Punkten erledigt'),
            Text('Erproben: ${completedFunctionChecks()} von 5 Punkten erledigt'),
            Text('Messungen: ${completedMeasurements()} von 120 Punkten erledigt'),
            const Divider(),
            const Text('Prüfablauf:'),
            const Text('1. Sichtprüfung'),
            const Text('2. Erproben / Funktionsprüfung'),
            const Text('3. Stringmessungen'),
            const Text('4. Prüfergebnis und Unterschrift'),
          ],
        ),
      ),
    );
  }

  Widget visualPhotoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: takeVisualInspectionPhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Foto zur Sichtprüfung aufnehmen'),
          ),
          if (visualInspectionPhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visualInspectionPhotos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          visualInspectionPhotos[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filledTonal(
                        onPressed: () => removeVisualInspectionPhoto(index),
                        icon: const Icon(Icons.close),
                        tooltip: 'Foto entfernen',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget visualInspectionSection() {
    return Card(
      child: Column(
        children: [
          const ListTile(
            title: Text('1. Sichtprüfung',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            subtitle: Text('Sichtbare und organisatorische Prüfpunkte.'),
          ),
          checkTile(
              title: 'Module sichtbar unbeschädigt',
              value: modulesOk,
              onChanged: (v) => setState(() => modulesOk = v ?? false)),
          checkTile(
              title: 'Leitungen geprüft',
              value: cablesOk,
              onChanged: (v) => setState(() => cablesOk = v ?? false)),
          checkTile(
              title: 'Steckverbinder geprüft',
              value: plugsOk,
              onChanged: (v) => setState(() => plugsOk = v ?? false)),
          checkTile(
              title: 'Kennzeichnung vorhanden',
              value: labelingOk,
              onChanged: (v) => setState(() => labelingOk = v ?? false)),
          checkTile(
              title: 'DC-Trennstelle / Schaltgerät vorhanden',
              value: dcSwitchOk,
              onChanged: (v) => setState(() => dcSwitchOk = v ?? false)),
          checkTile(
              title: 'Erdung / Potentialausgleich geprüft',
              value: groundingOk,
              onChanged: (v) => setState(() => groundingOk = v ?? false)),
          checkTile(
              title: 'Schutzmaßnahmen geprüft',
              value: protectionOk,
              onChanged: (v) => setState(() => protectionOk = v ?? false)),
          checkTile(
              title: 'Warnhinweise / Beschilderung geprüft',
              value: warningSignsOk,
              onChanged: (v) => setState(() => warningSignsOk = v ?? false)),
          visualPhotoSection(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: inputField('Bemerkung Sichtprüfung', visualNoteController,
                maxLines: 3),
          ),
        ],
      ),
    );
  }

  Widget functionTestSection() {
    return Card(
      child: Column(
        children: [
          const ListTile(
            title: Text('2. Erproben / Funktionsprüfung',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            subtitle: Text('Schalt-, Schutz- und Funktionsprüfungen.'),
          ),
          checkTile(
              title: 'Wechselrichter Funktion geprüft',
              value: inverterFunctionOk,
              onChanged: (v) => setState(() => inverterFunctionOk = v ?? false)),
          checkTile(
              title: 'DC-Trennschalter geprüft',
              value: dcDisconnectOk,
              onChanged: (v) => setState(() => dcDisconnectOk = v ?? false)),
          checkTile(
              title: 'AC-Trennstelle geprüft',
              value: acDisconnectOk,
              onChanged: (v) => setState(() => acDisconnectOk = v ?? false)),
          checkTile(
              title: 'Monitoring / Kommunikation geprüft',
              value: monitoringOk,
              onChanged: (v) => setState(() => monitoringOk = v ?? false)),
          checkTile(
              title: 'Abschaltung / Schaltfunktion geprüft',
              value: shutdownOk,
              onChanged: (v) => setState(() => shutdownOk = v ?? false)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: inputField('Bemerkung Erproben', functionNoteController,
                maxLines: 3),
          ),
        ],
      ),
    );
  }

  Widget measurementSection() {
    return Card(
      child: Column(
        children: [
          const ListTile(
            title: Text('3. Messen',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            subtitle: Text('Je String: Voc, Isc, Riso, Polarität und Ergebnis.'),
          ),
          for (var i = 0; i < 24; i++) stringMeasurementBlock(i),
          Padding(
            padding: const EdgeInsets.all(16),
            child: inputField('Bemerkung Messung', measurementNoteController,
                maxLines: 3),
          ),
        ],
      ),
    );
  }

  Widget stringMeasurementBlock(int index) {
    final stringNumber = index + 1;

    return Card(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PV-String Nr. $stringNumber',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),
            inputField('Voc [V DC]', vocControllers[index]),
            inputField('Isc [A]', iscControllers[index]),
            inputField('Riso [MOhm]', risoControllers[index]),
            CheckboxListTile(
              value: polarityOk[index],
              onChanged: (v) => setState(() => polarityOk[index] = v ?? false),
              title: const Text('Polarität geprüft'),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: green,
            ),
            CheckboxListTile(
              value: stringOk[index],
              onChanged: (v) => setState(() => stringOk[index] = v ?? false),
              title: const Text('String bestanden'),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: green,
            ),
          ],
        ),
      ),
    );
  }

  Widget signatureBox({
    required String title,
    required SignatureController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Signature(controller: controller, backgroundColor: Colors.white),
        ),
        TextButton.icon(
          onPressed: controller.clear,
          icon: const Icon(Icons.delete),
          label: const Text('Unterschrift löschen'),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget finalResultSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('4. Prüfergebnis und Unterschrift',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SwitchListTile(
              value: testPassed,
              onChanged: (value) => setState(() => testPassed = value),
              title: Text(testPassed
                  ? 'PV-Anlage bestanden'
                  : 'PV-Anlage nicht bestanden'),
              activeColor: green,
            ),
            inputField('Bemerkung zum Prüfergebnis', resultNoteController,
                maxLines: 3),
            signatureBox(
              title: 'Unterschrift Monteur',
              controller: technicianSignaturePad,
            ),
            signatureBox(
              title: 'Unterschrift Kunde',
              controller: customerSignaturePad,
            ),
            inputField('Allgemeine Bemerkung', generalNoteController,
                maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget actionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: createPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Abnahmeprotokoll erstellen'),
            ),
            if (pdfPath != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: openPdf,
                icon: const Icon(Icons.open_in_new),
                label: const Text('PDF öffnen'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget infoText() {
    return const Text(
      'Ablauf: Sichtprüfung, Erproben, Messen und abschließendes Prüfergebnis mit digitaler Unterschrift dokumentieren.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PV-Abnahmeprotokoll'),
        actions: [
          IconButton(
            onPressed: resetAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Zurücksetzen',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(),
            const SizedBox(height: 14),
            masterDataSection(),
            const SizedBox(height: 14),
            progressSection(),
            const SizedBox(height: 14),
            visualInspectionSection(),
            const SizedBox(height: 14),
            functionTestSection(),
            const SizedBox(height: 14),
            measurementSection(),
            const SizedBox(height: 14),
            finalResultSection(),
            const SizedBox(height: 14),
            actionSection(),
            const SizedBox(height: 12),
            infoText(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
