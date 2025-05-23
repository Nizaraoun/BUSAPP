import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoriqueTickets extends StatefulWidget {
  const HistoriqueTickets({Key? key}) : super(key: key);

  @override
  State<HistoriqueTickets> createState() => _HistoriqueTicketsState();
}

class _HistoriqueTicketsState extends State<HistoriqueTickets> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _chargerHistoriqueTickets();
  }

  Future<void> _chargerHistoriqueTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Récupérer l'ID utilisateur actuel via Firebase Auth
      final User? currentUser = FirebaseAuth.instance.currentUser;
      String? userId = currentUser?.uid;

      Query query = _firestore
          .collection('tickets')
          .orderBy('dateOperation', descending: true);

      // Si l'utilisateur est connecté, on filtre par son ID
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      QuerySnapshot querySnapshot = await query.get();

      List<Map<String, dynamic>> tickets = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        tickets.add({
          'id': doc.id,
          'nom': data['nom'] ?? 'N/A',
          'prenom': data['prenom'] ?? 'N/A',
          'ligne': data['ligne'] ?? 'N/A',
          'prix': data['prix'] ?? 0.0,
          'prixTotal': data['prixTotal'] ?? 0.0,
          'dateOperation': data['dateOperation'] ?? 'N/A',
          'numeroCarte': data['numeroCarte'] ?? 'N/A',
        });
      }

      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Erreur lors du chargement des tickets: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Tickets'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0E2A47),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorView()
                : _tickets.isEmpty
                    ? _buildEmptyView()
                    : _buildTicketsList(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _chargerHistoriqueTickets,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E2A47),
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    // Get current user to determine if we're showing a more specific message
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            color: Colors.grey[400],
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            currentUser != null
                ? 'Vous n\'avez pas encore acheté de tickets'
                : 'Aucun ticket dans l\'historique',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0E2A47),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentUser != null
                ? 'Les tickets achetés apparaîtront ici'
                : 'Connectez-vous pour voir vos tickets',
            style: const TextStyle(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    return RefreshIndicator(
      onRefresh: _chargerHistoriqueTickets,
      color: const Color(0xFF0E2A47),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        itemBuilder: (context, index) {
          final ticket = _tickets[index];
          return _buildTicketCard(ticket);
        },
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _afficherDetailsTicket(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ticket['ligne'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0E2A47),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2A47).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow('Date', ticket['dateOperation']),
              _buildInfoRow(
                  'Total payé', '${ticket['prixTotal'].toStringAsFixed(2)} DT'),
              _buildInfoRow('Passager', '${ticket['prenom']} ${ticket['nom']}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _afficherDetailsTicket(Map<String, dynamic> ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Détails du Ticket',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0E2A47),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),

                // Section Passager
                _buildSectionTitle('Informations Passager'),
                _buildDetailRow('Nom', '${ticket['prenom']} ${ticket['nom']}'),

                const SizedBox(height: 16),
                // Section Billet
                _buildSectionTitle('Informations Billet'),
                _buildDetailRow('Ligne', ticket['ligne']),
                _buildDetailRow(
                    'Prix unitaire', '${ticket['prix'].toStringAsFixed(2)} DT'),
              
                _buildDetailRow('Prix total',
                    '${ticket['prixTotal'].toStringAsFixed(2)} DT'),

                const SizedBox(height: 16),
                // Section Paiement
                _buildSectionTitle('Informations Paiement'),
                _buildDetailRow('Carte', ticket['numeroCarte']),
                _buildDetailRow('Date d\'opération', ticket['dateOperation']),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('TÉLÉCHARGER REÇU'),
                    onPressed: () {
                      _genererRecu(ticket);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF0E2A47),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0E2A47),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF555555),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _genererRecu(Map<String, dynamic> ticket) {
    // Show a dialog to preview the receipt before "downloading"
    showDialog(
      context: context,
      builder: (context) => _afficherDialogueRecu(ticket),
    );
  }

  Widget _afficherDialogueRecu(Map<String, dynamic> ticket) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SOTREGAMES',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF0E2A47),
                        ),
                      ),
                      const Text(
                        'Reçu de Ticket',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E2A47),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),

            // Receipt Number and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'N° de Reçu',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '#${ticket['id'].substring(0, 6).toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Date',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      ticket['dateOperation'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Customer Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INFORMATION CLIENT',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.person,
                          size: 16, color: Color(0xFF0E2A47)),
                      const SizedBox(width: 5),
                      Text(
                        '${ticket['prenom']} ${ticket['nom']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.credit_card,
                          size: 16, color: Color(0xFF0E2A47)),
                      const SizedBox(width: 5),
                      Text(
                        '${ticket['numeroCarte']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Ticket Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DÉTAILS DU TICKET',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ligne'),
                      Text(
                        ticket['ligne'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Prix unitaire'),
                      Text(
                        '${ticket['prix'].toStringAsFixed(2)} DT',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Nombre de tickets'),
                      
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${ticket['prixTotal'].toStringAsFixed(2)} DT',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0E2A47),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Footer action buttons
            Wrap(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('PARTAGER'),
                  onPressed: () {
                    Navigator.pop(context);
                    _partagerRecu(ticket);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0E2A47),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFF0E2A47)),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('ENREGISTRER'),
                  onPressed: () {
                    Navigator.pop(context);
                    _telechargerRecu(ticket);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E2A47),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _telechargerRecu(Map<String, dynamic> ticket) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Génération du reçu...'),
            ],
          ),
        ),
      ),
    );

    try {
      // Close loading dialog first to prevent context issues
      if (context.mounted) Navigator.pop(context);

      // Create PDF document
      final pdf = await _generateTicketPdf(ticket);

      // Show PDF preview with download option using the printing package
      if (context.mounted) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'Ticket_${ticket["id"].substring(0, 6).toUpperCase()}.pdf',
        );
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reçu généré avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's still open
      if (context.mounted) {
        // Check if there's a dialog to pop
        try {
          Navigator.pop(context);
        } catch (_) {}

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erreur lors de la génération du reçu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<pw.Document> _generateTicketPdf(Map<String, dynamic> ticket) async {
    // Load a font with Unicode support
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    final pdf = pw.Document();

    // Create PDF content
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SOTREGAMES',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 18,
                          ),
                        ),
                        pw.Text(
                          'Reçu de Ticket',
                          style: pw.TextStyle(
                            font: font,
                            color: PdfColors.grey,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blueGrey800,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Text(
                        'Gabes',
                        style: pw.TextStyle(
                          font: fontBold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Divider(height: 30),

                // Receipt Number and Date
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'N° de Reçu',
                          style: pw.TextStyle(
                            font: font,
                            color: PdfColors.grey,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          '#${ticket['id'].substring(0, 6).toUpperCase()}',
                          style: pw.TextStyle(
                            font: fontBold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Date',
                          style: pw.TextStyle(
                            font: font,
                            color: PdfColors.grey,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          ticket['dateOperation'],
                          style: pw.TextStyle(
                            font: fontBold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Customer Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INFORMATION CLIENT',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.grey,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        children: [
                          pw.Text(
                            '${ticket['prenom']} ${ticket['nom']}',
                            style: pw.TextStyle(
                              font: fontBold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Carte: ${ticket['numeroCarte']}',
                            style: pw.TextStyle(
                              font: font,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Ticket Details
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DÉTAILS DU TICKET',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.grey,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Ligne', style: pw.TextStyle(font: font)),
                          pw.Text(
                            ticket['ligne'],
                            style: pw.TextStyle(font: fontBold),
                          ),
                        ],
                      ),
                      pw.Divider(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Prix unitaire',
                              style: pw.TextStyle(font: font)),
                          pw.Text(
                            '${ticket['prix'].toStringAsFixed(2)} DT',
                            style: pw.TextStyle(font: fontBold),
                          ),
                        ],
                      ),
                      pw.Divider(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Nombre de tickets',
                              style: pw.TextStyle(font: font)),
                          
                        ],
                      ),
                      pw.Divider(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL',
                            style: pw.TextStyle(font: fontBold),
                          ),
                          pw.Text(
                            '${ticket['prixTotal'].toStringAsFixed(2)} DT',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 16,
                              color: PdfColors.blueGrey800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'Merci d\'avoir voyagé avec Sotregames',
                    style: pw.TextStyle(
                      font: fontItalic,
                      color: PdfColors.grey,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  void _partagerRecu(Map<String, dynamic> ticket) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Préparation du reçu pour partage...'),
            ],
          ),
        ),
      ),
    );

    try {
      // Generate PDF document using our helper method
      final pdf = await _generateTicketPdf(ticket);

      // Get app directory to save PDF
      final output = await getTemporaryDirectory();
      final String fileName =
          'Ticket_${ticket['id'].substring(0, 6).toUpperCase()}_${ticket['dateOperation'].replaceAll('/', '_').replaceAll(' ', '_')}.pdf';
      final file = File('${output.path}/$fileName');

      // Save PDF file
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Share PDF file
      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Reçu de ticket Sotregames',
          subject: 'Reçu de ticket Sotregames - ${ticket['ligne']}',
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage du reçu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
