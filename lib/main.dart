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

  bool isEnglish = false;

  String tr(String german, String english) => isEnglish ? english : german;

  void toggleLanguage() {
    setState(() => isEnglish = !isEnglish);
  }

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

  final SignatureController technicianSignaturePad = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  final SignatureController customerSignaturePad = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );

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
      showMessage(
        tr(
          'Spracheingabe nicht verfügbar. Bitte Mikrofonberechtigung prüfen.',
          'Voice input is unavailable. Please check the microphone permission.',
        ),
      );
      return;
    }

    setState(() {
      isListening = true;
      activeSpeechController = controller;
    });

    await speech.listen(
      localeId: isEnglish ? 'en_US' : 'de_DE',
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
    final cleaned = text
        .replaceAll(' Komma ', ',')
        .replaceAll(' komma ', ',')
        .replaceAll(' Punkt ', ',')
        .replaceAll(' punkt ', ',');
    return (isEnglish
        ? cleaned
        .replaceAll(' comma ', ',')
        .replaceAll(' period ', '.')
        .replaceAll(' full stop ', '.')
        : cleaned)
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
      showMessage(
        tr(
          'Kameraberechtigung fehlt. Bitte in den Android-Einstellungen erlauben.',
          'Camera permission is missing. Please allow it in the Android settings.',
        ),
      );
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

    final Uint8List? technicianSignatureBytes = await technicianSignaturePad
        .toPngBytes();
    final Uint8List? customerSignatureBytes = await customerSignaturePad
        .toPngBytes();

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
            tr('PV-Abnahmeprotokoll', 'PV Acceptance Report'),
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            tr(
              'Sichtprüfung · Erproben · Messen · Unterschrift',
              'Visual inspection · Functional testing · Measurements · Signatures',
            ),
          ),
          pw.Text(
            tr(
              'PV-Anlagenprüfung nach DIN EN 62446',
              'PV system inspection according to DIN EN 62446',
            ),
          ),
          pw.SizedBox(height: 20),

          pdfSection(tr('Kunde', 'Customer'), valueOf(customerController)),
          pdfSection(
            tr('Objekt / Standort', 'Site / Location'),
            valueOf(objectController),
          ),
          pdfSection(
            tr('Anlagennummer', 'System number'),
            valueOf(plantNumberController),
          ),
          pdfSection(
            tr('Modulfeld', 'PV array'),
            valueOf(moduleFieldController),
          ),
          pdfSection(
            tr('Wechselrichter', 'Inverter'),
            valueOf(inverterController),
          ),
          pdfSection(
            tr('Modulhersteller', 'Module manufacturer'),
            valueOf(moduleManufacturerController),
          ),
          pdfSection(
            tr('Modultyp', 'Module type'),
            valueOf(moduleTypeController),
          ),
          pdfSection(
            tr('Anzahl Module', 'Number of modules'),
            valueOf(moduleCountController),
          ),
          pdfSection(
            tr('Generatorleistung', 'Generator capacity'),
            valueOf(generatorPowerController),
          ),
          pdfSection(
            tr('Monteur', 'Technician'),
            valueOf(technicianController),
          ),
          pdfSection(tr('Datum', 'Date'), valueOf(dateController)),

          pw.SizedBox(height: 18),
          pw.Text(
            tr('1. Sichtprüfung', '1. Visual inspection'),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pdfCheck(
            tr('Module sichtbar unbeschädigt', 'Modules visibly undamaged'),
            modulesOk,
          ),
          pdfCheck(tr('Leitungen geprüft', 'Cables checked'), cablesOk),
          pdfCheck(tr('Steckverbinder geprüft', 'Connectors checked'), plugsOk),
          pdfCheck(
            tr('Kennzeichnung vorhanden', 'Labelling present'),
            labelingOk,
          ),
          pdfCheck(
            tr(
              'DC-Trennstelle / Schaltgerät vorhanden',
              'DC isolator / switching device present',
            ),
            dcSwitchOk,
          ),
          pdfCheck(
            tr(
              'Erdung / Potentialausgleich geprüft',
              'Grounding / equipotential bonding checked',
            ),
            groundingOk,
          ),
          pdfCheck(
            tr('Schutzmaßnahmen geprüft', 'Protective measures checked'),
            protectionOk,
          ),
          pdfCheck(
            tr(
              'Warnhinweise / Beschilderung geprüft',
              'Warnings / signage checked',
            ),
            warningSignsOk,
          ),
          pdfSection(
            tr('Bemerkung Sichtprüfung', 'Visual inspection notes'),
            valueOf(visualNoteController),
          ),
          if (visualInspectionPhotoBytes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              tr('Fotos Sichtprüfung', 'Visual inspection photos'),
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
                  child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
                );
              }).toList(),
            ),
          ],

          pw.SizedBox(height: 18),
          pw.Text(
            tr('2. Erproben / Funktionsprüfung', '2. Functional testing'),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pdfCheck(
            tr('Wechselrichter Funktion geprüft', 'Inverter function checked'),
            inverterFunctionOk,
          ),
          pdfCheck(
            tr('DC-Trennschalter geprüft', 'DC isolator checked'),
            dcDisconnectOk,
          ),
          pdfCheck(
            tr('AC-Trennstelle geprüft', 'AC isolator checked'),
            acDisconnectOk,
          ),
          pdfCheck(
            tr(
              'Monitoring / Kommunikation geprüft',
              'Monitoring / communication checked',
            ),
            monitoringOk,
          ),
          pdfCheck(
            tr(
              'Abschaltung / Schaltfunktion geprüft',
              'Shutdown / switching function checked',
            ),
            shutdownOk,
          ),
          pdfSection(
            tr('Bemerkung Erproben', 'Functional test notes'),
            valueOf(functionNoteController),
          ),

          pw.SizedBox(height: 18),
          pw.Text(
            tr('3. Messungen', '3. Measurements'),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          measurementTable(),
          pw.SizedBox(height: 12),
          pdfSection(
            tr('Bemerkung Messung', 'Measurement notes'),
            valueOf(measurementNoteController),
          ),

          pw.SizedBox(height: 18),
          pw.Text(
            tr('4. Prüfergebnis', '4. Test result'),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pdfSection(
            tr('Ergebnis', 'Result'),
            testPassed
                ? tr('PV-Anlage bestanden', 'PV system passed')
                : tr('PV-Anlage nicht bestanden', 'PV system failed'),
          ),
          pdfSection(
            tr('Bemerkung Ergebnis', 'Result notes'),
            valueOf(resultNoteController),
          ),
          pdfSection(
            tr('Allgemeine Bemerkung', 'General notes'),
            valueOf(generalNoteController),
          ),

          pw.SizedBox(height: 18),
          pw.Text(
            tr('5. Unterschriften', '5. Signatures'),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: signaturePdfBox(
                  title: tr('Unterschrift Monteur', 'Technician signature'),
                  bytes: technicianSignatureBytes,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: signaturePdfBox(
                  title: tr('Unterschrift Kunde', 'Customer signature'),
                  bytes: customerSignatureBytes,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),
          pw.Text(
            tr(
              'Hinweis: Die Ergebnisse und Unterschriften wurden digital erfasst und sind vor Weitergabe fachlich zu prüfen.',
              'Note: The results and signatures were recorded digitally and must be professionally reviewed before distribution.',
            ),
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

    showMessage(
      tr(
        'PDF-Abnahmeprotokoll wurde erstellt.',
        'The PV acceptance report PDF has been created.',
      ),
    );
  }

  pw.Widget pdfSection(String title, String content) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 155,
            child: pw.Text(
              title,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
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
          tableHeader(tr('Polarität', 'Polarity')),
          tableHeader(tr('Ergebnis', 'Result')),
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
            tableCell(stringOk[i] ? tr('Bestanden', 'Passed') : '-'),
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
              ? pw.Center(
            child: pw.Text(tr('Keine Unterschrift', 'No signature')),
          )
              : pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
        ),
      ],
    );
  }

  Future<void> openPdf() async {
    if (pdfPath == null) {
      showMessage(
        tr(
          'Bitte zuerst Abnahmeprotokoll erstellen.',
          'Please create the acceptance report first.',
        ),
      );
      return;
    }

    await OpenFilex.open(pdfPath!);
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('PV-Abnahmeprotokoll', 'PV Acceptance Report'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Sichtprüfung · Erproben · Messen',
              'Visual inspection · Functional testing · Measurements',
            ),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'Dokumentation nach DIN EN 62446',
              'Documentation according to DIN EN 62446',
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget inputField(
      String label,
      TextEditingController controller, {
        int maxLines = 1,
      }) {
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
            onPressed: active
                ? stopSpeechInput
                : () => startSpeechInput(controller),
            icon: Icon(active ? Icons.stop : Icons.mic),
            tooltip: tr('Spracheingabe', 'Voice input'),
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
            Text(
              tr('Anlagendaten', 'System details'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            inputField(tr('Kunde', 'Customer'), customerController),
            inputField(
              tr('Objekt / Standort', 'Site / Location'),
              objectController,
            ),
            inputField(
              tr('Anlagennummer', 'System number'),
              plantNumberController,
            ),
            inputField(tr('Modulfeld', 'PV array'), moduleFieldController),
            inputField(tr('Wechselrichter', 'Inverter'), inverterController),
            inputField(
              tr('Modulhersteller', 'Module manufacturer'),
              moduleManufacturerController,
            ),
            inputField(tr('Modultyp', 'Module type'), moduleTypeController),
            inputField(
              tr('Anzahl Module', 'Number of modules'),
              moduleCountController,
            ),
            inputField(
              tr('Generatorleistung (kWp)', 'Generator capacity (kWp)'),
              generatorPowerController,
            ),
            inputField(tr('Monteur', 'Technician'), technicianController),
            inputField(tr('Datum', 'Date'), dateController),
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
            Text(
              tr('Prüfübersicht', 'Inspection overview'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                'Sichtprüfung: ${completedVisualChecks()} von 8 Punkten erledigt',
                'Visual inspection: ${completedVisualChecks()} of 8 items completed',
              ),
            ),
            Text(
              tr(
                'Erproben: ${completedFunctionChecks()} von 5 Punkten erledigt',
                'Functional testing: ${completedFunctionChecks()} of 5 items completed',
              ),
            ),
            Text(
              tr(
                'Messungen: ${completedMeasurements()} von 120 Punkten erledigt',
                'Measurements: ${completedMeasurements()} of 120 items completed',
              ),
            ),
            const Divider(),
            Text(tr('Prüfablauf:', 'Inspection sequence:')),
            Text(tr('1. Sichtprüfung', '1. Visual inspection')),
            Text(tr('2. Erproben / Funktionsprüfung', '2. Functional testing')),
            Text(tr('3. Stringmessungen', '3. String measurements')),
            Text(
              tr(
                '4. Prüfergebnis und Unterschrift',
                '4. Test result and signatures',
              ),
            ),
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
            label: Text(
              tr(
                'Foto zur Sichtprüfung aufnehmen',
                'Take visual inspection photo',
              ),
            ),
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
                        tooltip: tr('Foto entfernen', 'Remove photo'),
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
          ListTile(
            title: Text(
              tr('1. Sichtprüfung', '1. Visual inspection'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              tr(
                'Sichtbare und organisatorische Prüfpunkte.',
                'Visual and organisational inspection items.',
              ),
            ),
          ),
          checkTile(
            title: tr(
              'Module sichtbar unbeschädigt',
              'Modules visibly undamaged',
            ),
            value: modulesOk,
            onChanged: (v) => setState(() => modulesOk = v ?? false),
          ),
          checkTile(
            title: tr('Leitungen geprüft', 'Cables checked'),
            value: cablesOk,
            onChanged: (v) => setState(() => cablesOk = v ?? false),
          ),
          checkTile(
            title: tr('Steckverbinder geprüft', 'Connectors checked'),
            value: plugsOk,
            onChanged: (v) => setState(() => plugsOk = v ?? false),
          ),
          checkTile(
            title: tr('Kennzeichnung vorhanden', 'Labelling present'),
            value: labelingOk,
            onChanged: (v) => setState(() => labelingOk = v ?? false),
          ),
          checkTile(
            title: tr(
              'DC-Trennstelle / Schaltgerät vorhanden',
              'DC isolator / switching device present',
            ),
            value: dcSwitchOk,
            onChanged: (v) => setState(() => dcSwitchOk = v ?? false),
          ),
          checkTile(
            title: tr(
              'Erdung / Potentialausgleich geprüft',
              'Grounding / equipotential bonding checked',
            ),
            value: groundingOk,
            onChanged: (v) => setState(() => groundingOk = v ?? false),
          ),
          checkTile(
            title: tr('Schutzmaßnahmen geprüft', 'Protective measures checked'),
            value: protectionOk,
            onChanged: (v) => setState(() => protectionOk = v ?? false),
          ),
          checkTile(
            title: tr(
              'Warnhinweise / Beschilderung geprüft',
              'Warnings / signage checked',
            ),
            value: warningSignsOk,
            onChanged: (v) => setState(() => warningSignsOk = v ?? false),
          ),
          visualPhotoSection(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: inputField(
              tr('Bemerkung Sichtprüfung', 'Visual inspection notes'),
              visualNoteController,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget functionTestSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              tr('2. Erproben / Funktionsprüfung', '2. Functional testing'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              tr(
                'Schalt-, Schutz- und Funktionsprüfungen.',
                'Switching, protection and functional tests.',
              ),
            ),
          ),
          checkTile(
            title: tr(
              'Wechselrichter Funktion geprüft',
              'Inverter function checked',
            ),
            value: inverterFunctionOk,
            onChanged: (v) => setState(() => inverterFunctionOk = v ?? false),
          ),
          checkTile(
            title: tr('DC-Trennschalter geprüft', 'DC isolator checked'),
            value: dcDisconnectOk,
            onChanged: (v) => setState(() => dcDisconnectOk = v ?? false),
          ),
          checkTile(
            title: tr('AC-Trennstelle geprüft', 'AC isolator checked'),
            value: acDisconnectOk,
            onChanged: (v) => setState(() => acDisconnectOk = v ?? false),
          ),
          checkTile(
            title: tr(
              'Monitoring / Kommunikation geprüft',
              'Monitoring / communication checked',
            ),
            value: monitoringOk,
            onChanged: (v) => setState(() => monitoringOk = v ?? false),
          ),
          checkTile(
            title: tr(
              'Abschaltung / Schaltfunktion geprüft',
              'Shutdown / switching function checked',
            ),
            value: shutdownOk,
            onChanged: (v) => setState(() => shutdownOk = v ?? false),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: inputField(
              tr('Bemerkung Erproben', 'Functional test notes'),
              functionNoteController,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget measurementSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              tr('3. Messen', '3. Measurements'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              tr(
                'Je String: Voc, Isc, Riso, Polarität und Ergebnis.',
                'For each string: Voc, Isc, Riso, polarity and result.',
              ),
            ),
          ),
          for (var i = 0; i < 24; i++) stringMeasurementBlock(i),
          Padding(
            padding: const EdgeInsets.all(16),
            child: inputField(
              tr('Bemerkung Messung', 'Measurement notes'),
              measurementNoteController,
              maxLines: 3,
            ),
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
              tr('PV-String Nr. $stringNumber', 'PV string no. $stringNumber'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),
            inputField('Voc [V DC]', vocControllers[index]),
            inputField('Isc [A]', iscControllers[index]),
            inputField('Riso [MOhm]', risoControllers[index]),
            CheckboxListTile(
              value: polarityOk[index],
              onChanged: (v) => setState(() => polarityOk[index] = v ?? false),
              title: Text(tr('Polarität geprüft', 'Polarity checked')),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: green,
            ),
            CheckboxListTile(
              value: stringOk[index],
              onChanged: (v) => setState(() => stringOk[index] = v ?? false),
              title: Text(tr('String bestanden', 'String passed')),
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
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Signature(
            controller: controller,
            backgroundColor: Colors.white,
          ),
        ),
        TextButton.icon(
          onPressed: controller.clear,
          icon: const Icon(Icons.delete),
          label: Text(tr('Unterschrift löschen', 'Clear signature')),
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
            Text(
              tr(
                '4. Prüfergebnis und Unterschrift',
                '4. Test result and signatures',
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: testPassed,
              onChanged: (value) => setState(() => testPassed = value),
              title: Text(
                testPassed
                    ? tr('PV-Anlage bestanden', 'PV system passed')
                    : tr('PV-Anlage nicht bestanden', 'PV system failed'),
              ),
              activeColor: green,
            ),
            inputField(
              tr('Bemerkung zum Prüfergebnis', 'Test result notes'),
              resultNoteController,
              maxLines: 3,
            ),
            signatureBox(
              title: tr('Unterschrift Monteur', 'Technician signature'),
              controller: technicianSignaturePad,
            ),
            signatureBox(
              title: tr('Unterschrift Kunde', 'Customer signature'),
              controller: customerSignaturePad,
            ),
            inputField(
              tr('Allgemeine Bemerkung', 'General notes'),
              generalNoteController,
              maxLines: 3,
            ),
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
              label: Text(
                tr('Abnahmeprotokoll erstellen', 'Create acceptance report'),
              ),
            ),
            if (pdfPath != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: openPdf,
                icon: const Icon(Icons.open_in_new),
                label: Text(tr('PDF öffnen', 'Open PDF')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget infoText() {
    return Text(
      tr(
        'Ablauf: Sichtprüfung, Erproben, Messen und abschließendes Prüfergebnis mit digitaler Unterschrift dokumentieren.',
        'Process: Document the visual inspection, functional tests, measurements and final test result with digital signatures.',
      ),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('PV-Abnahmeprotokoll', 'PV Acceptance Report')),
        actions: [
          Tooltip(
            message: isEnglish ? 'Auf Deutsch wechseln' : 'Switch to English',
            child: TextButton.icon(
              onPressed: toggleLanguage,
              icon: const Icon(Icons.language, color: Colors.white),
              label: Text(
                isEnglish ? 'DE' : 'EN',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
          IconButton(
            onPressed: resetAll,
            icon: const Icon(Icons.refresh),
            tooltip: tr('Zurücksetzen', 'Reset'),
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
