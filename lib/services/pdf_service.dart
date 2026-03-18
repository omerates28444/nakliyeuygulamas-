import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  // Bu fonksiyon bilgileri alır ve bir PDF dosyası (byte dizisi) üretir
  static Future<Uint8List> generateEcmrPdf({
    required String fromCity,
    required String toCity,
    required String driverName,
    required String shipperName,
    required String price,
    required Uint8List signatureBytes,
    required String role, // İmzayı kimin attığını belirtmek için
  }) async {
    final pdf = pw.Document();

    // İmzayı PDF'in anlayacağı bir resim formatına çeviriyoruz
    final signatureImage = pw.MemoryImage(signatureBytes);

    // Güncel tarihi alıyoruz
    final dateStr = "${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}";

    // A4 formatında yeni bir sayfa ekliyoruz
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // BAŞLIK (LOGIMAP LOGOSU/YAZISI)
              pw.Center(
                child: pw.Text(
                  "LOGIMAP",
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  "DIJITAL TASIMA IRSALIYESI (e-CMR)",
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 30),

              // GENEL BİLGİLER KUTUSU
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Tarih: $dateStr", style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 8),
                    pw.Text("Yuk Sahibi: $shipperName", style: const pw.TextStyle(fontSize: 12)),
                    pw.Text("Tasimaci (Sofor): $driverName", style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // TAŞIMA DETAYLARI
              pw.Text("TASIMA DETAYLARI", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Alinis Yeri:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(fromCity),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Teslim Yeri:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(toCity),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Anlasilan Ucret:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("$price TL"),
                ],
              ),
              pw.SizedBox(height: 40),

              // İMZA ALANI
              pw.Text("ONAY VE IMZA", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 20),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        role == "driver" ? "Tasimaci Imzasi" : "Yuk Sahibi Imzasi",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 10),
                      // Ekranda çizilen imzayı buraya basıyoruz
                      pw.Container(
                        height: 80,
                        width: 150,
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                        child: pw.Image(signatureImage),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // ALT BİLGİ (FOOTER)
              pw.Center(
                child: pw.Text(
                  "Bu belge LogiMap uygulamasi uzerinden guvenli bir sekilde dijital olarak olusturulmustur.",
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              )
            ],
          );
        },
      ),
    );

    // Oluşturulan PDF'i byte (veri) olarak döndürüyoruz
    return pdf.save();
  }
}