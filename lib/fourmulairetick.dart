import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FormulaireTicket extends StatefulWidget {
  const FormulaireTicket({Key? key, required String title}) : super(key: key);

  @override
  State<FormulaireTicket> createState() => _FormulaireTicketState();
}

class _FormulaireTicketState extends State<FormulaireTicket> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs de texte
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _cinController = TextEditingController();
  final TextEditingController _nombreTicketsController =
      TextEditingController(text: '1');
  final TextEditingController _prixController = TextEditingController();

  // Instance Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variables pour les lignes et le prix
  List<Map<String, dynamic>> _lignes = [];
  String? _ligneSelectionnee;
  double _prixUnitaire = 0.0;
  double _prixTotal = 0.0;

  // Résultat après paiement
  bool _paiementEffectue = false;
  Map<String, dynamic> _resultats = {};

  @override
  void initState() {
    super.initState();
    _chargerLignesBus();

    // Ajouter les listeners pour calculer le prix total
    _prixController.addListener(_calculerPrixTotal);
    _nombreTicketsController.addListener(_calculerPrixTotal);
  }

  // Fonction pour calculer le prix total
  void _calculerPrixTotal() {
    if (_prixController.text.isNotEmpty &&
        _nombreTicketsController.text.isNotEmpty) {
      try {
        double prix = double.parse(_prixController.text);
        int nombre = int.parse(_nombreTicketsController.text);
        setState(() {
          _prixTotal = prix * nombre;
        });
      } catch (e) {
        setState(() {
          _prixTotal = 0.0;
        });
      }
    } else {
      setState(() {
        _prixTotal = 0.0;
      });
    }
  }

  // Fonction pour charger les lignes de bus régionales
  Future<void> _chargerLignesBus() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('buses')
          .where('description', isEqualTo: 'regional')
          .get();

      List<Map<String, dynamic>> lignes = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        lignes.add({
          'id': doc.id,
          'lignename': data['lignename'] ?? 'Ligne sans nom',
          'prix': data['prix'] ?? 0.0,
        });
      }

      setState(() {
        _lignes = lignes;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur de chargement des lignes: ${e.toString()}')),
      );
    }
  }

  // Fonction pour mettre à jour le prix lorsqu'une ligne est sélectionnée
  void _mettreAJourPrix(String? ligneId) {
    if (ligneId != null) {
      final ligne = _lignes.firstWhere(
        (element) => element['id'] == ligneId,
        orElse: () => {'prix': 0.0},
      );

      setState(() {
        _ligneSelectionnee = ligneId;
        _prixUnitaire = (ligne['prix'] is num) ? ligne['prix'].toDouble() : 0.0;
        _prixController.text = _prixUnitaire.toString();
      });
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _cinController.dispose();
    _prixController.dispose();
    _nombreTicketsController.dispose();
    super.dispose();
  }

  // Fonction pour enregistrer les données dans Firebase
  Future<void> _enregistrerDonnees() async {
    if (_formKey.currentState!.validate()) {
      // Date actuelle formatée
      String dateOperation =
          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      // Récupérer le nom de la ligne
      String ligneName = '';
      if (_ligneSelectionnee != null) {
        final ligne = _lignes.firstWhere(
          (element) => element['id'] == _ligneSelectionnee,
          orElse: () => {'lignename': 'Inconnu'},
        );
        ligneName = ligne['lignename'];
      }

      // Données à enregistrer
      Map<String, dynamic> donnees = {
        'nom': _nomController.text,
        'prenom': _prenomController.text,
        'cin': _cinController.text,
        'ligne': ligneName,
        'ligneId': _ligneSelectionnee,
        'prix': _prixUnitaire,
        'nombreTickets': int.parse(_nombreTicketsController.text),
        'prixTotal': _prixTotal,
        'dateOperation': dateOperation,
      };

      // Enregistrement dans Firestore
      try {
        await _firestore.collection('tickets').add(donnees);

        setState(() {
          _paiementEffectue = true;
          _resultats = donnees;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement effectué avec succès!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulaire de Ticket'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _paiementEffectue ? _afficherResultat() : _afficherFormulaire(),
      ),
    );
  }

  Widget _afficherFormulaire() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre nom';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _prenomController,
              decoration: const InputDecoration(
                labelText: 'Prénom',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre prénom';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cinController,
              decoration: const InputDecoration(
                labelText: 'CIN (8 chiffres)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 8,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir votre CIN';
                }
                if (value.length != 8 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'Le CIN doit contenir exactement 8 chiffres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Sélection de la ligne (dropdown)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Ligne demandée',
                border: OutlineInputBorder(),
              ),
              value: _ligneSelectionnee,
              hint: const Text('Choisir une ligne'),
              isExpanded: true,
              items: _lignes.map((ligne) {
                return DropdownMenuItem<String>(
                  value: ligne['id'],
                  child: Text(ligne['lignename']),
                );
              }).toList(),
              onChanged: (value) => _mettreAJourPrix(value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez sélectionner une ligne';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Prix unitaire (désactivé car automatiquement rempli)
            TextFormField(
              controller: _prixController,
              decoration: const InputDecoration(
                labelText: 'Prix unitaire',
                border: OutlineInputBorder(),
                prefixText: 'DT ',
              ),
              keyboardType: TextInputType.number,
              readOnly: true, // Lecture seule
              enabled: false, // Désactivé
            ),

            const SizedBox(height: 16),

            // Nombre de tickets
            TextFormField(
              controller: _nombreTicketsController,
              decoration: const InputDecoration(
                labelText: 'Nombre de tickets',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le nombre de tickets';
                }
                try {
                  int nombreTickets = int.parse(value);
                  if (nombreTickets <= 0) {
                    return 'Le nombre de tickets doit être supérieur à 0';
                  }
                } catch (e) {
                  return 'Veuillez entrer un nombre entier valide';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Affichage du prix total
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Prix total:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${_prixTotal.toStringAsFixed(2)} DT',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF0E2A47),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed:
                  _ligneSelectionnee != null ? _enregistrerDonnees : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF0E2A47),
                foregroundColor: Colors.white,
              ),
              child: const Text('PAYER', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _afficherResultat() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Détails du paiement',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(thickness: 2),
            const SizedBox(height: 16),
            _infoRow('Nom', '${_resultats['prenom']} ${_resultats['nom']}'),
            _infoRow('CIN', _resultats['cin']),
            _infoRow('Ligne demandée', _resultats['ligne']),
            _infoRow(
                'Prix unitaire', '${_resultats['prix'].toStringAsFixed(2)} DT'),
            _infoRow('Nombre de tickets', '${_resultats['nombreTickets']}'),
            _infoRow('Prix total',
                '${_resultats['prixTotal'].toStringAsFixed(2)} DT'),
            _infoRow('Date d\'opération', _resultats['dateOperation']),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _paiementEffectue = false;
                  _nomController.clear();
                  _prenomController.clear();
                  _cinController.clear();
                  _prixController.clear();
                  _ligneSelectionnee = null;
                  _nombreTicketsController.text =
                      '1'; // Réinitialiser à 1 ticket par défaut
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E2A47),
                foregroundColor: Colors.white,
              ),
              child: const Text('Nouveau ticket'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
