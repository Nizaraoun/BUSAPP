import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/historique_tickets.dart';

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
  final TextEditingController _numeroCarteController = TextEditingController();
  final TextEditingController _dateExpirationController =
      TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _nombreTicketsController =
      TextEditingController(text: '1');
  final TextEditingController _prixController = TextEditingController();

  // Instance Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variables pour les étapes de paiement
  int _etapeActuelle = 0;
  bool _paiementEnCours = false;

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
      QuerySnapshot querySnapshot =
          await _firestore.collection('regional').get();

      List<Map<String, dynamic>> lignes = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        lignes.add({
          'id': doc.id,
          'Linename': data['Linename'] ?? 'Ligne sans nom',
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
    _numeroCarteController.dispose();
    _dateExpirationController.dispose();
    _cvcController.dispose();
    _prixController.dispose();
    _nombreTicketsController.dispose();
    super.dispose();
  }

  // Simuler un processus de paiement avec délai
  Future<void> _simulerPaiement() async {
    setState(() {
      _paiementEnCours = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (_formKey.currentState!.validate()) {
      await _enregistrerDonnees();
    }

    setState(() {
      _paiementEnCours = false;
    });
  }

  // Fonction pour enregistrer les données dans Firebase
  Future<void> _enregistrerDonnees() async {
    if (_formKey.currentState!.validate()) {
      // Date actuelle formatée
      String dateOperation =
          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      // Récupérer le nom de la ligne
      String Linename = '';
      if (_ligneSelectionnee != null) {
        final ligne = _lignes.firstWhere(
          (element) => element['id'] == _ligneSelectionnee,
          orElse: () => {'Linename': 'Inconnu'},
        );
        Linename = ligne['Linename'];
      }

      // Données à enregistrer
      Map<String, dynamic> donnees = {
        'nom': _nomController.text,
        'prenom': _prenomController.text,
        'numeroCarte': _maskCardNumber(_numeroCarteController.text),
        'dateExpiration': _dateExpirationController.text,
        'ligne': Linename,
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
          _etapeActuelle = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement effectué avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Masquer le numéro de carte pour la sécurité
  String _maskCardNumber(String cardNumber) {
    if (cardNumber.length < 8) return cardNumber;
    return cardNumber.replaceRange(
        4, cardNumber.length - 4, '*' * (cardNumber.length - 8));
  }

  // Avancer à l'étape suivante
  void _avancerEtape() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _etapeActuelle = 1;
      });
    }
  }

  // Revenir à l'étape précédente
  void _revenirEtape() {
    setState(() {
      _etapeActuelle = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achat de Ticket'),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              _paiementEffectue ? _afficherResultat() : _afficherFormulaire(),
        ),
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
            // Indicateur d'étape
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      color: const Color(0xFF0E2A47),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF0E2A47),
                    child: Text(
                      '1',
                      style: TextStyle(
                        color:
                            _etapeActuelle == 0 ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      color: _etapeActuelle >= 1
                          ? const Color(0xFF0E2A47)
                          : Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _etapeActuelle >= 1
                        ? const Color(0xFF0E2A47)
                        : Colors.grey.shade300,
                    child: Text(
                      '2',
                      style: TextStyle(
                        color: _etapeActuelle == 1
                            ? Colors.white
                            : (_etapeActuelle > 1
                                ? Colors.white70
                                : Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Titre de l'étape
            Text(
              _etapeActuelle == 0
                  ? 'Détails du billet'
                  : 'Informations de paiement',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0E2A47),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Étape 1: Détails du billet
            if (_etapeActuelle == 0) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informations personnelles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Champs pour le nom et prénom
                      TextFormField(
                        controller: _nomController,
                        decoration: InputDecoration(
                          labelText: 'Nom',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.person),
                          filled: true,
                          fillColor: Colors.white,
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
                        decoration: InputDecoration(
                          labelText: 'Prénom',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre prénom';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Détails du trajet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sélection de la ligne
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Ligne demandée',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.directions_bus),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _ligneSelectionnee,
                        hint: const Text('Choisir une ligne'),
                        isExpanded: true,
                        items: _lignes.map((ligne) {
                          return DropdownMenuItem<String>(
                            value: ligne['id'],
                            child: Text(ligne['Linename']),
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

                      // Prix unitaire
                      TextFormField(
                        controller: _prixController,
                        decoration: InputDecoration(
                          labelText: 'Prix unitaire',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                          prefixText: 'DT ',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        readOnly: true,
                        enabled: false,
                      ),
                      const SizedBox(height: 16),

                      // Nombre de tickets
                      TextFormField(
                        controller: _nombreTicketsController,
                        decoration: InputDecoration(
                          labelText: 'Nombre de tickets',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.confirmation_number),
                          filled: true,
                          fillColor: Colors.white,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Prix total
              Card(
                elevation: 2,
                color: const Color(0xFF0E2A47),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Prix total:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_prixTotal.toStringAsFixed(2)} DT',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton pour passer à l'étape suivante
              ElevatedButton(
                onPressed: _ligneSelectionnee != null ? _avancerEtape : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF0E2A47),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
                child: const Text(
                  'CONTINUER VERS LE PAIEMENT',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],

            // Étape 2: Paiement
            if (_etapeActuelle == 1) ...[
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image de carte de crédit
                      Center(
                        child: Container(
                          height: 80,
                          margin: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.credit_card,
                                  size: 40, color: Colors.blue.shade800),
                              const SizedBox(width: 8),
                              Icon(Icons.payment,
                                  size: 40, color: Colors.red.shade800),
                              const SizedBox(width: 8),
                              Icon(Icons.account_balance_wallet,
                                  size: 40, color: Colors.amber.shade800),
                            ],
                          ),
                        ),
                      ),

                      const Text(
                        'Informations de carte de crédit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E2A47),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Numéro de carte
                      TextFormField(
                        controller: _numeroCarteController,
                        decoration: InputDecoration(
                          labelText: 'Numéro de carte',
                          hintText: 'XXXX XXXX XXXX XXXX',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.credit_card),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez saisir votre numéro de carte';
                          }
                          if (value.length != 16) {
                            return 'Le numéro de carte doit contenir 16 chiffres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Ligne avec date d'expiration et CVC
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dateExpirationController,
                              decoration: InputDecoration(
                                labelText: 'Date d\'expiration',
                                hintText: 'MM/AA',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: const Icon(Icons.date_range),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.datetime,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(5),
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9/]')),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Requis';
                                }
                                if (!RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$')
                                    .hasMatch(value)) {
                                  return 'Format MM/AA';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                if (value.length == 2 && !value.contains('/')) {
                                  _dateExpirationController.text = '$value/';
                                  _dateExpirationController.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: _dateExpirationController
                                            .text.length),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cvcController,
                              decoration: InputDecoration(
                                labelText: 'CVC',
                                hintText: '123',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: const Icon(Icons.security),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Requis';
                                }
                                if (value.length != 3) {
                                  return '3 chiffres';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Résumé de la commande
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Résumé de la commande',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ligne:'),
                          Text(
                            _lignes.firstWhere(
                              (ligne) => ligne['id'] == _ligneSelectionnee,
                              orElse: () => {'Linename': 'Inconnue'},
                            )['Linename'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tickets:'),
                          Text(
                            _nombreTicketsController.text,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Prix unitaire:'),
                          Text(
                            '${_prixUnitaire.toStringAsFixed(2)} DT',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Prix Total:',
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Boutons de navigation
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _revenirEtape,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: const Color(0xFF0E2A47),
                        side: const BorderSide(color: Color(0xFF0E2A47)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('RETOUR'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _paiementEnCours ? null : _simulerPaiement,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF0E2A47),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3,
                      ),
                      child: _paiementEnCours
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('CONFIRMER PAIEMENT'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _afficherResultat() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0E2A47),
                    const Color(0xFF0E2A47).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Paiement réussi !',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Transaction confirmée: ${_resultats['dateOperation']}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('TÉLÉCHARGER REÇU'),
                    onPressed: () => _telechargerRecu(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      side: const BorderSide(color: Colors.white),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Détails du ticket',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0E2A47),
                    ),
                  ),
                  const Divider(thickness: 1),
                  const SizedBox(height: 16),
                  _infoRow('Passager',
                      '${_resultats['prenom']} ${_resultats['nom']}'),
                  _infoRow('Ligne', _resultats['ligne']),
                  _infoRow('Prix unitaire',
                      '${_resultats['prix'].toStringAsFixed(2)} DT'),
                  _infoRow(
                      'Nombre de tickets', '${_resultats['nombreTickets']}'),
                  _infoRow('Prix total',
                      '${_resultats['prixTotal'].toStringAsFixed(2)} DT'),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'Paiement',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0E2A47),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoRow('Carte', _resultats['numeroCarte']),
                  _infoRow('Date', _resultats['dateExpiration']),
                  _infoRow('Date d\'opération', _resultats['dateOperation']),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('NOUVEAU TICKET'),
                  onPressed: () {
                    setState(() {
                      _paiementEffectue = false;
                      _nomController.clear();
                      _prenomController.clear();
                      _numeroCarteController.clear();
                      _dateExpirationController.clear();
                      _cvcController.clear();
                      _prixController.clear();
                      _ligneSelectionnee = null;
                      _nombreTicketsController.text = '1';
                      _etapeActuelle = 0;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    backgroundColor: const Color(0xFF0E2A47),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('VOIR HISTORIQUE'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HistoriqueTickets()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0E2A47),
                    side: const BorderSide(color: Color(0xFF0E2A47)),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  void _telechargerRecu() {
    // Show a dialog to preview the receipt before "downloading"
    showDialog(
      context: context,
      builder: (context) => _afficherDialogueRecu(),
    );
  }

  Widget _afficherDialogueRecu() {
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
                        'BUS TRACKER',
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
                      '#${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 13)}',
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
                      _resultats['dateOperation'],
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
                        '${_resultats['prenom']} ${_resultats['nom']}',
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
                        _resultats['numeroCarte'],
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
                        _resultats['ligne'],
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
                        '${_resultats['prix'].toStringAsFixed(2)} DT',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Nombre de tickets'),
                      Text(
                        '${_resultats['nombreTickets']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                        '${_resultats['prixTotal'].toStringAsFixed(2)} DT',
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('PARTAGER'),
                  onPressed: () {
                    Navigator.pop(context);
                    _partagerRecu();
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
                    _simulerTelechargement();
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

  void _partagerRecu() {
    // In a real implementation, you would generate the PDF file and share it
    // Since we don't have the PDF library installed, we'll simulate this with a message
    final String messageText = """
REÇU DE TICKET - BUS TRACKER
N° ${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 13)}
Date: ${_resultats['dateOperation']}

Client: ${_resultats['prenom']} ${_resultats['nom']}
Ligne: ${_resultats['ligne']}
Prix unitaire: ${_resultats['prix'].toStringAsFixed(2)} DT
Nombre de tickets: ${_resultats['nombreTickets']}
TOTAL: ${_resultats['prixTotal'].toStringAsFixed(2)} DT

Merci d'avoir voyagé avec Bus Tracker!
    """;

    // This would normally share the messageText, but we're simulating
    print(messageText); // Print to console to use the variable

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reçu partagé avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _simulerTelechargement() {
    // Simulate a download process with a loading dialog followed by success message
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
              Text('Téléchargement du reçu...'),
            ],
          ),
        ),
      ),
    );

    // Simulate process completion after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reçu téléchargé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }
}
