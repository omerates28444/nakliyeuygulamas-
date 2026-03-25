import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  // 🟢 İki imzayı da alabilmesi ve daha fazla detay göstermesi için parametreleri güncelledik
  static Future<Uint8List> generateEcmrPdf({
    String documentId = "LM-2026-001", // Rastgele veya veritabanından gelen belge no
    required String fromCity,
    required String toCity,
    required String driverName,
    required String shipperName,
    required String price,
    String weight = "-",
    String plate = "-",
    Uint8List? shipperSignatureBytes, // 1. İmza
    Uint8List? driverSignatureBytes,  // 2. İmza
  }) async {
    final pdf = pw.Document();

    // Gelen imzaları PDF formatına (MemoryImage) çevir, eğer imza yoksa null bırak
    pw.MemoryImage? shipperImage;
    if (shipperSignatureBytes != null) {
      shipperImage = pw.MemoryImage(shipperSignatureBytes);
    }

    pw.MemoryImage? driverImage;
    if (driverSignatureBytes != null) {
      driverImage = pw.MemoryImage(driverSignatureBytes);
    }

    // Güncel tarihi al (Örn: 17.03.2026)
    final dateStr = "${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}";

    // LogiMap Kurumsal Renkleri (PDF için)
    final navy = PdfColor.fromHex('#081226');
    final blue = PdfColor.fromHex('#1976D2');
    final lightGrey = PdfColor.fromHex('#F5F5F5');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40), // Kenar boşlukları
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🟢 BAŞLIK ALANI 🟢
              pw.Center(
                child: pw.Text("LOGIMAP", style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: navy)),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text("DIJITAL TASIMA IRSALIYESI (e-CMR)", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: blue)),
              ),
              pw.SizedBox(height: 30),

              // 🟢 BÖLÜM 1: TARAFLAR VE TARİH 🟢
              pw.Text("TARAFLAR VE TARIH BILGISI", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: navy)),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                cellPadding: const pw.EdgeInsets.all(8),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 11),
                columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1)},
                data: [
                  ["Irsaliye No: $documentId", "Tarih: $dateStr"],
                  ["Gonderici (Yuk Sahibi): $shipperName", ""],
                  ["Tasiyici (Sofor): $driverName", "Arac Plakasi: $plate"],
                ],
              ),
              pw.SizedBox(height: 24),

              // 🟢 BÖLÜM 2: TAŞIMA DETAYLARI 🟢
              pw.Text("TASIMA DETAYLARI", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: navy)),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                cellPadding: const pw.EdgeInsets.all(8),
                cellStyle: const pw.TextStyle(fontSize: 11),
                columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(2.5)},
                data: [
                  ["Alinis Yeri:", fromCity],
                  ["Teslim Yeri:", toCity],
                  ["Yuk Agirligi:", "$weight kg"],
                  ["Anlasilan Ucret:", "$price TL"],
                ],
              ),
              pw.SizedBox(height: 40),

              // 🟢 BÖLÜM 3: ONAY VE İMZA ALANI (ÇİFT SÜTUN) 🟢
              pw.Text("ONAY VE IMZA", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: navy)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [

                  // SOL KUTU: YÜK SAHİBİ İMZASI
                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                      child: pw.Column(
                        children: [
                          pw.Container(
                            width: double.infinity, color: lightGrey, padding: const pw.EdgeInsets.all(6),
                            child: pw.Center(child: pw.Text("1. Yuk Sahibi (Gonderici) Onayi", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(shipperName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ),
                          pw.Container(
                            height: 80, width: 140, margin: const pw.EdgeInsets.only(bottom: 12),
                            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200, style: pw.BorderStyle.dashed)),
                            child: shipperImage != null
                                ? pw.Image(shipperImage, fit: pw.BoxFit.contain)
                                : pw.Center(child: pw.Text("Imza Bekleniyor", style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 10))),
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 20), // İki imza arası boşluk

                  // SAĞ KUTU: ŞOFÖR İMZASI
                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                      child: pw.Column(
                        children: [
                          pw.Container(
                            width: double.infinity, color: lightGrey, padding: const pw.EdgeInsets.all(6),
                            child: pw.Center(child: pw.Text("2. Tasiyici (Sofor) Onayi", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(driverName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ),
                          pw.Container(
                            height: 80, width: 140, margin: const pw.EdgeInsets.only(bottom: 12),
                            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200, style: pw.BorderStyle.dashed)),
                            child: driverImage != null
                                ? pw.Image(driverImage, fit: pw.BoxFit.contain)
                                : pw.Center(child: pw.Text("Imza Bekleniyor", style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 10))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // 🟢 ALT BİLGİ (FOOTER) 🟢
              pw.Center(
                child: pw.Text(
                  "Bu e-CMR belgesi LogiMap Akilli Nakliye Platformu uzerinden $dateStr tarihinde dijital olarak uretilmistir.\n5070 Sayili Elektronik Imza Kanunu kapsaminda kayit altindadir.",
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              )
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}