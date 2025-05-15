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

class HistoriqueAbonnements extends StatefulWidget {
  const HistoriqueAbonnements({Key? key}) : super(key: key);

  @override
  State<HistoriqueAbonnements> createState() => _HistoriqueAbonnementsState();
}

class _HistoriqueAbonnementsState extends State<HistoriqueAbonnements> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _abonnements = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _chargerHistoriqueAbonnements();
  }

  Future<void> _chargerHistoriqueAbonnements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Récupérer l'ID utilisateur actuel via Firebase Auth
      final User? currentUser = FirebaseAuth.instance.currentUser;
      String? userId = currentUser?.uid;

      Query query = _firestore
          .collection('abonnements')
          .orderBy('dateOperation', descending: true);

      // Si l'utilisateur est connecté, on filtre par son ID
      if (userId != null) {
        print('User ID: $userId');
        query = query.where('userId', isEqualTo: userId);
      }

      QuerySnapshot querySnapshot = await query.get();

      List<Map<String, dynamic>> abonnements = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        abonnements.add({
          'id': doc.id,
          'nom': data['nom'] ?? 'N/A',
          'prenom': data['prenom'] ?? 'N/A',
          'dateNaissance': data['dateNaissance'] ?? 'N/A',
          'classe': data['classe'] ?? 'N/A',
          'ligne': data['ligne'] ?? 'N/A',
          'depart': data['depart'] ?? 'N/A',
          'arret': data['arret'] ?? 'N/A',
          'typeAbonnement': data['typeAbonnement'] ?? 'N/A',
          'prix': data['prix'] ?? 0.0,
          'dateOperation': data['dateOperation'] ?? 'N/A',
          'dateFinAbonnement': data['dateFinAbonnement'] ?? 'N/A',
          'numeroCarte': data['numeroCarte'] ?? 'N/A',
        });
      }

      setState(() {
        _abonnements = abonnements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Erreur lors du chargement des abonnements: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Abonnements'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0E2A47),
        foregroundColor: Colors.white,
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
                : _abonnements.isEmpty
                    ? _buildEmptyView()
                    : _buildAbonnementsList(),
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
            onPressed: _chargerHistoriqueAbonnements,
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
            Icons.card_membership,
            color: Colors.grey[400],
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            currentUser != null
                ? 'Vous n\'avez pas encore souscrit d\'abonnement'
                : 'Aucun abonnement dans l\'historique',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0E2A47),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentUser != null
                ? 'Les abonnements souscrits apparaîtront ici'
                : 'Connectez-vous pour voir vos abonnements',
            style: const TextStyle(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAbonnementsList() {
    return RefreshIndicator(
      onRefresh: _chargerHistoriqueAbonnements,
      color: const Color(0xFF0E2A47),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _abonnements.length,
        itemBuilder: (context, index) {
          final abonnement = _abonnements[index];
          return _buildAbonnementCard(abonnement);
        },
      ),
    );
  }

  Widget _buildAbonnementCard(Map<String, dynamic> abonnement) {
    // Vérifier si l'abonnement est actif ou expiré
    bool isExpired = false;
    try {
      final dateFinParts = abonnement['dateFinAbonnement'].split('/');
      if (dateFinParts.length == 3) {
        final dateFinJour = int.parse(dateFinParts[0]);
        final dateFinMois = int.parse(dateFinParts[1]);
        final dateFinAnnee = int.parse(dateFinParts[2]);

        final dateFin = DateTime(dateFinAnnee, dateFinMois, dateFinJour);
        isExpired = dateFin.isBefore(DateTime.now());
      }
    } catch (e) {
      // En cas d'erreur de parsing, on considère que l'abonnement est valide
      isExpired = false;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _afficherDetailsAbonnement(abonnement),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      abonnement['ligne'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0E2A47),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isExpired ? 'Expiré' : 'Actif',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isExpired ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E2A47).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  abonnement['typeAbonnement'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0E2A47),
                  ),
                ),
              ),
              const Divider(),
              _buildInfoRow(
                  'Abonné', '${abonnement['prenom']} ${abonnement['nom']}'),
              _buildInfoRow('Début', abonnement['dateOperation']),
              _buildInfoRow('Fin', abonnement['dateFinAbonnement']),
              _buildInfoRow(
                  'Prix', '${abonnement['prix'].toStringAsFixed(2)} DT'),
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

  void _afficherDetailsAbonnement(Map<String, dynamic> abonnement) {
    // Vérifier si l'abonnement est actif ou expiré
    bool isExpired = false;
    try {
      final dateFinParts = abonnement['dateFinAbonnement'].split('/');
      if (dateFinParts.length == 3) {
        final dateFinJour = int.parse(dateFinParts[0]);
        final dateFinMois = int.parse(dateFinParts[1]);
        final dateFinAnnee = int.parse(dateFinParts[2]);

        final dateFin = DateTime(dateFinAnnee, dateFinMois, dateFinJour);
        isExpired = dateFin.isBefore(DateTime.now());
      }
    } catch (e) {
      // En cas d'erreur de parsing, on considère que l'abonnement est valide
      isExpired = false;
    }

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
                Wrap(
                  children: [
                    const Text(
                      'Détails de l\'Abonnement',
                      style: TextStyle(
                        fontSize: 20,
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
                        color: isExpired
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isExpired ? 'Expiré' : 'Actif',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isExpired ? Colors.red : Colors.green,
                        ),
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

                // Section Abonné
                _buildSectionTitle('Informations Abonné'),
                _buildDetailRow(
                    'Nom', '${abonnement['prenom']} ${abonnement['nom']}'),
                _buildDetailRow(
                    'Date de naissance', abonnement['dateNaissance']),
                if (abonnement['classe'] != null &&
                    abonnement['classe'] != 'N/A')
                  _buildDetailRow('Classe', abonnement['classe']),

                const SizedBox(height: 16),
                // Section Abonnement
                _buildSectionTitle('Informations Abonnement'),
                _buildDetailRow('Type', abonnement['typeAbonnement']),
                _buildDetailRow('Ligne', abonnement['ligne']),
                _buildDetailRow('Départ', abonnement['depart']),
                _buildDetailRow('Arrivée', abonnement['arret']),
                _buildDetailRow('Date de début', abonnement['dateOperation']),
                _buildDetailRow('Date de fin', abonnement['dateFinAbonnement']),
                _buildDetailRow(
                    'Prix', '${abonnement['prix'].toStringAsFixed(2)} DT'),

                const SizedBox(height: 16),
                // Section Paiement
                _buildSectionTitle('Informations Paiement'),
                _buildDetailRow('Carte', abonnement['numeroCarte']),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('TÉLÉCHARGER REÇU'),
                    onPressed: () {
                      _genererRecu(abonnement);
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

  void _genererRecu(Map<String, dynamic> abonnement) {
    // Show a dialog to preview the receipt before "downloading"
    showDialog(
      context: context,
      builder: (context) => _afficherDialogueRecu(abonnement),
    );
  }

  Widget _afficherDialogueRecu(Map<String, dynamic> abonnement) {
    // Vérifier si l'abonnement est actif ou expiré
    bool isExpired = false;
    try {
      final dateFinParts = abonnement['dateFinAbonnement'].split('/');
      if (dateFinParts.length == 3) {
        final dateFinJour = int.parse(dateFinParts[0]);
        final dateFinMois = int.parse(dateFinParts[1]);
        final dateFinAnnee = int.parse(dateFinParts[2]);

        final dateFin = DateTime(dateFinAnnee, dateFinMois, dateFinJour);
        isExpired = dateFin.isBefore(DateTime.now());
      }
    } catch (e) {
      // En cas d'erreur de parsing, on considère que l'abonnement est valide
      isExpired = false;
    }

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
                        'Reçu d\'Abonnement',
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
                    Icons.card_membership,
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
                      '#${abonnement['id'].substring(0, 6).toUpperCase()}',
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
                      'Statut',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      isExpired ? 'EXPIRÉ' : 'ACTIF',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isExpired ? Colors.red : Colors.green,
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
                        '${abonnement['prenom']} ${abonnement['nom']}',
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
                        '${abonnement['numeroCarte']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (abonnement['classe'] != null &&
                      abonnement['classe'] != 'N/A') ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.school,
                            size: 16, color: Color(0xFF0E2A47)),
                        const SizedBox(width: 5),
                        Text(
                          '${abonnement['classe']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Subscription Details
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
                    'DÉTAILS DE L\'ABONNEMENT',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Type'),
                      Text(
                        abonnement['typeAbonnement'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ligne'),
                      Text(
                        abonnement['ligne'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Wrap(
                    children: [
                      const Text('Période'),
                      Text(
                        '${abonnement['dateOperation']} au ${abonnement['dateFinAbonnement']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PRIX',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${abonnement['prix'].toStringAsFixed(2)} DT',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('PARTAGER'),
                    onPressed: () {
                      Navigator.pop(context);
                      _partagerRecu(abonnement);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0E2A47),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF0E2A47)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('ENREGISTRER'),
                    onPressed: () {
                      Navigator.pop(context);
                      _telechargerRecu(abonnement);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E2A47),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _telechargerRecu(Map<String, dynamic> abonnement) async {
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
      final pdf = await _generateAbonnementPdf(abonnement);

      // Show PDF preview with download option using the printing package
      if (context.mounted) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name:
              'Abonnement_${abonnement["id"].substring(0, 6).toUpperCase()}.pdf',
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

  Future<pw.Document> _generateAbonnementPdf(
      Map<String, dynamic> abonnement) async {
    // Load a font with Unicode support
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    // Vérifier si l'abonnement est actif ou expiré
    bool isExpired = false;
    try {
      final dateFinParts = abonnement['dateFinAbonnement'].split('/');
      if (dateFinParts.length == 3) {
        final dateFinJour = int.parse(dateFinParts[0]);
        final dateFinMois = int.parse(dateFinParts[1]);
        final dateFinAnnee = int.parse(dateFinParts[2]);

        final dateFin = DateTime(dateFinAnnee, dateFinMois, dateFinJour);
        isExpired = dateFin.isBefore(DateTime.now());
      }
    } catch (e) {
      // En cas d'erreur de parsing, on considère que l'abonnement est valide
      isExpired = false;
    }

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
                          'Reçu d\'Abonnement',
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

                // Receipt Number and Status
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
                          '#${abonnement['id'].substring(0, 6).toUpperCase()}',
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
                          'Statut',
                          style: pw.TextStyle(
                            font: font,
                            color: PdfColors.grey,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          isExpired ? 'EXPIRÉ' : 'ACTIF',
                          style: pw.TextStyle(
                            font: fontBold,
                            color: isExpired ? PdfColors.red : PdfColors.green,
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
                            'Nom: ${abonnement['prenom']} ${abonnement['nom']}',
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
                            'Date de naissance: ${abonnement['dateNaissance']}',
                            style: pw.TextStyle(
                              font: font,
                            ),
                          ),
                        ],
                      ),
                      if (abonnement['classe'] != null &&
                          abonnement['classe'] != 'N/A')
                        pw.SizedBox(height: 5),
                      if (abonnement['classe'] != null &&
                          abonnement['classe'] != 'N/A')
                        pw.Row(
                          children: [
                            pw.Text(
                              'Classe: ${abonnement['classe']}',
                              style: pw.TextStyle(
                                font: font,
                              ),
                            ),
                          ],
                        ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Carte: ${abonnement['numeroCarte']}',
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

                // Abonnement Details
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
                        'DÉTAILS DE L\'ABONNEMENT',
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
                          pw.Text('Type d\'abonnement',
                              style: pw.TextStyle(font: font)),
                          pw.Text(
                            abonnement['typeAbonnement'],
                            style: pw.TextStyle(font: fontBold),
                          ),
                        ],
                      ),
                      pw.Divider(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Ligne', style: pw.TextStyle(font: font)),
                          pw.Text(
                            abonnement['ligne'],
                            style: pw.TextStyle(font: fontBold),
                          ),
                        ],
                      ),
                      pw.Divider(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Départ', style: pw.TextStyle(font: font)),
                          pw.Text(
                            abonnement['depart'],
                            style: pw.TextStyle(font: fontBold),
                          ),
                        ],
                      ),
                      pw.Divider(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Arrivée', style: pw.TextStyle(font: font)),
                          pw.Text(
                            abonnement['arret'],
                            style: pw.TextStyle(font: fontBold),
                          ),
                        ],
                      ),
                      pw.Divider(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Date d\'achat',
                              style: pw.TextStyle(font: font)),
                          pw.Text(
                            abonnement['dateOperation'],
                            style: pw.TextStyle(font: fontBold),
                          ),
                        ],
                      ),
                      pw.Divider(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Date d\'expiration',
                              style: pw.TextStyle(font: font)),
                          pw.Text(
                            abonnement['dateFinAbonnement'],
                            style: pw.TextStyle(font: fontBold),
                          ),
                        ],
                      ),
                      pw.Divider(height: 16),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'PRIX TOTAL',
                            style: pw.TextStyle(font: fontBold),
                          ),
                          pw.Text(
                            '${abonnement['prix'].toStringAsFixed(2)} DT',
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

  void _partagerRecu(Map<String, dynamic> abonnement) async {
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
      final pdf = await _generateAbonnementPdf(abonnement);

      // Get app directory to save PDF
      final output = await getTemporaryDirectory();
      final String fileName =
          'Abonnement_${abonnement['id'].substring(0, 6).toUpperCase()}_${abonnement['dateOperation'].replaceAll('/', '_').replaceAll(' ', '_')}.pdf';
      final file = File('${output.path}/$fileName');

      // Save PDF file
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Share PDF file
      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Reçu d\'abonnement Sotregames',
          subject: 'Reçu d\'abonnement Sotregames - ${abonnement['ligne']}',
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
