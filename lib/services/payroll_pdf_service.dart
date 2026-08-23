import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/formatters.dart';
import '../data/models.dart';
import '../data/operational_models.dart';

class PayrollPdfService {
  const PayrollPdfService();

  Future<void> shareRole({
    required Company company,
    required PayrollPeriodRecord period,
    required PayrollEntryRecord entry,
  }) async {
    final document = pw.Document(
      title: 'Rol de pago - ${entry.employeeName}',
      author: 'Laboral EC',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 42,
                height: 42,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#12344A'),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  'LE',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      company.displayName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (company.ruc?.isNotEmpty ?? false)
                      pw.Text('RUC ${company.ruc}'),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Rol de pago · ${period.label}',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#5B6764'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 28),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F3F7F6'),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              children: [
                _row('Trabajador', entry.employeeName),
                _row('Identificación', entry.identificationNumber),
                _row('Cargo', entry.position),
                _row('Periodo', period.label),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Ingresos y descuentos',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          _moneyRow('Sueldo base', entry.baseSalary),
          if (entry.grossIncome > entry.baseSalary)
            _moneyRow(
              'Horas adicionales / otros ingresos',
              entry.grossIncome - entry.baseSalary,
            ),
          _moneyRow('Ingreso bruto', entry.grossIncome, strong: true),
          pw.Divider(color: PdfColor.fromHex('#DCE4E1')),
          _moneyRow('Aporte personal IESS', -entry.employeeIess),
          if (entry.otherDeductions > 0)
            _moneyRow('Otros descuentos', -entry.otherDeductions),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#D7F2ED'),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: _moneyRow('Neto a pagar', entry.netPay, strong: true),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Información del empleador',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          _moneyRow('Aporte patronal IESS', entry.employerIess),
          _moneyRow('Costo laboral estimado', entry.employerCost),
          pw.SizedBox(height: 34),
          pw.Row(
            children: [
              pw.Expanded(child: _signature('Empleador')),
              pw.SizedBox(width: 36),
              pw.Expanded(child: _signature('Trabajador')),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Documento generado por Laboral EC. Los valores deben verificarse frente a novedades y particularidades del periodo antes de su uso definitivo.',
            style: pw.TextStyle(
              fontSize: 8.5,
              color: PdfColor.fromHex('#6B7572'),
            ),
          ),
        ],
      ),
    );

    final safeName = entry.employeeName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'rol_${period.year}_${period.month}_$safeName.pdf',
    );
  }

  pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(color: PdfColor.fromHex('#5B6764')),
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

  pw.Widget _moneyRow(String label, double value, {bool strong = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.Text(
              money(value),
              style: pw.TextStyle(
                fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: strong ? 13 : 11,
              ),
            ),
          ],
        ),
      );

  pw.Widget _signature(String label) => pw.Column(
        children: [
          pw.SizedBox(height: 38),
          pw.Container(height: 1, color: PdfColor.fromHex('#8A9491')),
          pw.SizedBox(height: 5),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ],
      );
}
