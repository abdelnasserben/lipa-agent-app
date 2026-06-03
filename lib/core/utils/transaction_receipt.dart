import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/enums.dart';
import '../../data/models/transaction.dart';
import 'formatters.dart';

/// Builds the share/PDF artefacts for an agent transaction receipt and the
/// wallet statement. Pure presentation logic so the activity detail and the
/// statement screen reuse the exact same rendering. Mirrors the Lipa customer
/// app's `transaction_receipt.dart`, adapted to the agent's wallet-scoped
/// [AgentTransaction] / [StatementEntry] models.

/// PDF theme backed by a real TrueType font. The default PDF font (Helvetica)
/// lacks the Unicode minus sign U+2212 used in amounts (it renders as a missing
/// glyph / tofu box), so we load Open Sans — which covers it — via printing's
/// Google Fonts helper. The font bytes are cached after the first download.
Future<pw.ThemeData> _pdfTheme() async => pw.ThemeData.withFont(
      base: await PdfGoogleFonts.openSansRegular(),
      bold: await PdfGoogleFonts.openSansBold(),
    );

/// French status label, matching `TxStatusPill`.
String _statusLabelFr(TransactionStatus s) => switch (s) {
      TransactionStatus.completed => 'Effectué',
      TransactionStatus.pending => 'En attente',
      TransactionStatus.authorized => 'Autorisé',
      TransactionStatus.declined => 'Refusé',
      TransactionStatus.expired => 'Expiré',
      TransactionStatus.reversed => 'Annulé',
      TransactionStatus.unknown => '—',
    };

/// A plain-text recap suitable for the native share sheet.
String receiptShareText(AgentTransaction t) {
  final incoming = t.incoming;
  final sign = incoming ? '+' : '−';
  final at = t.effectiveAt;
  final lines = <String>[
    'Reçu Lipa',
    '',
    'Opération : ${t.type.frLabel}',
    'Montant : $sign${fmtKmfNoUnit(t.requestedAmount)} KMF',
    'Statut : ${_statusLabelFr(t.status)}',
    if (at != null) 'Date : ${fmtDateTimeFr(at)}',
    if (t.feeAmount > 0) 'Frais : ${fmtKmfNoUnit(t.feeAmount)} KMF',
    if (t.commissionAmount > 0)
      'Commission : ${fmtKmfNoUnit(t.commissionAmount)} KMF',
    'Montant net : ${fmtKmfNoUnit(t.netAmountToDestination)} KMF',
    'Référence : ${t.id}',
  ];
  return lines.join('\n');
}

/// Renders the agent receipt as a printable/shareable PDF document.
Future<Uint8List> receiptPdfBytes(AgentTransaction t) async {
  final doc = pw.Document(theme: await _pdfTheme());
  final incoming = t.incoming;
  final sign = incoming ? '+' : '−';
  final at = t.effectiveAt;

  const ink = PdfColor.fromInt(0xFF171717);
  const inkMid = PdfColor.fromInt(0xFF5A5852);
  const inkLow = PdfColor.fromInt(0xFF8A8780);
  const brand = PdfColor.fromInt(0xFF386851);
  const line = PdfColor.fromInt(0xFFE6E3DC);

  pw.Widget row(String label, String value, {bool last = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        decoration: last
            ? null
            : const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.8)),
              ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(color: inkMid, fontSize: 11)),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Text(
                value,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(color: ink, fontSize: 11),
              ),
            ),
          ],
        ),
      );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Lipa',
              style: pw.TextStyle(
                  color: brand, fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Reçu de transaction',
              style: const pw.TextStyle(color: inkLow, fontSize: 12)),
          pw.SizedBox(height: 28),
          pw.Text(t.type.frLabel,
              style: pw.TextStyle(
                  color: ink, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 18),
          pw.Text('$sign${fmtKmfNoUnit(t.requestedAmount)} KMF',
              style: pw.TextStyle(
                  color: ink, fontSize: 30, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 28),
          row('Statut', _statusLabelFr(t.status)),
          if (at != null) row('Date', fmtDateTimeFr(at)),
          row('Type', t.type.frLabel),
          if (t.feeAmount > 0)
            row('Frais', '${fmtKmfNoUnit(t.feeAmount)} KMF'),
          if (t.commissionAmount > 0)
            row('Commission', '${fmtKmfNoUnit(t.commissionAmount)} KMF'),
          row('Montant net', '${fmtKmfNoUnit(t.netAmountToDestination)} KMF'),
          row('Référence', t.id, last: true),
          pw.Spacer(),
          pw.Text(
            'Ce reçu est généré par l’application Lipa à titre informatif.',
            style: const pw.TextStyle(color: inkLow, fontSize: 9),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

/// Renders a wallet statement (a date window's entries with running balance)
/// as a printable/shareable PDF. [from]/[to] are the chosen window, null = all.
Future<Uint8List> statementPdfBytes(
  List<StatementEntry> entries, {
  DateTime? from,
  DateTime? to,
}) async {
  final doc = pw.Document(theme: await _pdfTheme());

  const ink = PdfColor.fromInt(0xFF171717);
  const inkMid = PdfColor.fromInt(0xFF5A5852);
  const inkLow = PdfColor.fromInt(0xFF8A8780);
  const brand = PdfColor.fromInt(0xFF386851);
  const credit = PdfColor.fromInt(0xFF386851);
  const line = PdfColor.fromInt(0xFFE6E3DC);
  const headerBg = PdfColor.fromInt(0xFFF1EFE8);

  final period = (from == null && to == null)
      ? 'Toute la période'
      : '${from != null ? fmtDateTimeFr(from) : '…'} → '
          '${to != null ? fmtDateTimeFr(to) : '…'}';

  pw.Widget cell(String text,
          {pw.TextAlign align = pw.TextAlign.left,
          PdfColor color = ink,
          bool bold = false}) =>
      pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));

  pw.TableRow headerRow() => pw.TableRow(
        decoration: const pw.BoxDecoration(color: headerBg),
        children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell('Date', bold: true, color: inkMid)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell('Description', bold: true, color: inkMid)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell('Montant',
                  align: pw.TextAlign.right, bold: true, color: inkMid)),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: cell('Solde',
                  align: pw.TextAlign.right, bold: true, color: inkMid)),
        ],
      );

  pw.TableRow entryRow(StatementEntry e) {
    final isCredit = e.entryType.isCredit;
    return pw.TableRow(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: line, width: 0.6)),
      ),
      children: [
        pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: cell(e.postedAt != null ? fmtDateTimeFr(e.postedAt!) : '—',
                color: inkMid)),
        pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: cell(e.descriptionFr)),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: cell(
            '${isCredit ? '+' : '−'}${fmtKmfNoUnit(e.amount)}',
            align: pw.TextAlign.right,
            color: isCredit ? credit : ink,
          ),
        ),
        pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: cell(fmtKmfNoUnit(e.runningBalance),
                align: pw.TextAlign.right, color: inkMid)),
      ],
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 44, 36, 44),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text('Relevé Lipa',
                  style: const pw.TextStyle(color: inkLow, fontSize: 9)),
            ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(color: inkLow, fontSize: 9)),
      ),
      build: (context) => [
        pw.Text('Lipa',
            style: pw.TextStyle(
                color: brand, fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('Relevé du portefeuille',
            style: const pw.TextStyle(color: inkLow, fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Text('Période : $period',
            style: const pw.TextStyle(color: inkMid, fontSize: 10)),
        pw.SizedBox(height: 16),
        if (entries.isEmpty)
          pw.Text('Aucune écriture sur cette période.',
              style: const pw.TextStyle(color: inkLow, fontSize: 11))
        else
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(2.4),
              1: pw.FlexColumnWidth(3.2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              headerRow(),
              ...entries.map(entryRow),
            ],
          ),
      ],
    ),
  );

  return doc.save();
}
