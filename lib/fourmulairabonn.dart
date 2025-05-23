import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/historique_abonnements.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FormulaireAbonnement extends StatefulWidget {
  const FormulaireAbonnement({Key? key}) : super(key: key);

  @override
  State<FormulaireAbonnement> createState() => _FormulaireAbonnementState();
}

class _FormulaireAbonnementState extends State<FormulaireAbonnement> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _dateNaissanceController =
      TextEditingController();
  final TextEditingController _classeController = TextEditingController();
  final TextEditingController _numeroCarteController = TextEditingController();
  final TextEditingController _dateExpirationController =
      TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _prixController = TextEditingController();
  final TextEditingController _cinController = TextEditingController();
  final TextEditingController _adressController = TextEditingController();
  final TextEditingController _nomPrenomParentsController =
      TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _etapeActuelle = 0;
  bool _paiementEnCours = false;

  List<Map<String, dynamic>> _lignes = [];
  String? _ligneSelectionnee;
  String? _departSelectionnee;
  String? _arretSelectionnee;
  double _prixAbonnement = 0.0;
  String _typeAbonnement = 'Trimestriel'; // Par défaut

  final List<String> _typesAbonnement = [
    'Trimestriel',
    'semestrielle',
    'Annuel'
  ];

  final Map<String, double> _facteursPrix = {
    'Trimestriel': 1.0,
    'semestrielle': 2.7,
    'Annuel': 10.0,
  };

  bool _paiementEffectue = false;
  Map<String, dynamic> _resultats = {};

  @override
  void initState() {
    super.initState();
    _chargerLignesBus();

    _dateNaissanceController.text = '';
  }

  Future<void> _chargerLignesBus() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('ligne').get();

      List<Map<String, dynamic>> lignes = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String depart = data['depart'] ?? '';
        String arret = data['arret'] ?? '';
        lignes.add({
          'id': doc.id,
          'Linename': depart.isNotEmpty && arret.isNotEmpty
              ? '$depart - $arret'
              : 'Ligne sans nom',
          'prix': data['prix'] ?? 0.0,
          'depart': depart,
          'arret': arret,
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

  void _mettreAJourInfosLigne(String? ligneId) {
    if (ligneId != null) {
      final ligne = _lignes.firstWhere(
        (element) => element['id'] == ligneId,
        orElse: () => {'prix': 0.0, 'depart': '', 'arret': ''},
      );

      setState(() {
        _ligneSelectionnee = ligneId;
        _departSelectionnee = ligne['depart'];
        _arretSelectionnee = ligne['arret'];
        _prixAbonnement =
            (ligne['prix'] is num) ? ligne['prix'].toDouble() : 0.0;
        _prixController.text = _calculerPrixTotal().toString();
      });
    }
  }

  double _calculerPrixTotal() {
    return _prixAbonnement * (_facteursPrix[_typeAbonnement] ?? 1.0);
  }

  void _mettreAJourTypeAbonnement(String? type) {
    if (type != null) {
      setState(() {
        _typeAbonnement = type;
        _prixController.text = _calculerPrixTotal().toString();
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0E2A47),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateNaissanceController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _dateNaissanceController.dispose();
    _classeController.dispose();
    _numeroCarteController.dispose();
    _dateExpirationController.dispose();
    _cvcController.dispose();
    _prixController.dispose();
    super.dispose();
  }

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

  Future<void> _enregistrerDonnees() async {
    if (_formKey.currentState!.validate()) {
      DateTime dateFin;
      DateTime maintenant = DateTime.now();

      switch (_typeAbonnement) {
        case 'Trimestriel':
          dateFin =
              DateTime(maintenant.year, maintenant.month + 1, maintenant.day);
          break;
        case 'semestrielle':
          dateFin =
              DateTime(maintenant.year, maintenant.month + 3, maintenant.day);
          break;
        case 'Annuel':
          dateFin =
              DateTime(maintenant.year + 1, maintenant.month, maintenant.day);
          break;
        default:
          dateFin =
              DateTime(maintenant.year, maintenant.month + 1, maintenant.day);
      }

      String dateOperation = DateFormat('dd/MM/yyyy HH:mm').format(maintenant);
      String dateExpiration = DateFormat('dd/MM/yyyy').format(dateFin);

      String lineName = 'Inconnu';
      if (_ligneSelectionnee != null) {
        final ligne = _lignes.firstWhere(
          (element) => element['id'] == _ligneSelectionnee,
          orElse: () => {'depart': '', 'arret': ''},
        );
        String depart = ligne['depart'] ?? '';
        String arret = ligne['arret'] ?? '';
        lineName = depart.isNotEmpty && arret.isNotEmpty
            ? '$depart - $arret'
            : 'Ligne sans nom';
      }

      String userId = 'anonymous';
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          userId = currentUser.uid;
        }
      } catch (e) {
        print("Erreur récupération utilisateur: $e");
      }

      Map<String, dynamic> donnees = {
        'nom': _nomController.text,
        'prenom': _prenomController.text,
        'dateNaissance': _dateNaissanceController.text,
        'classe': _classeController.text,
        'numeroCarte': _maskCardNumber(_numeroCarteController.text),
        'dateExpiration': _dateExpirationController.text,
        'ligne': lineName,
        'ligneId': _ligneSelectionnee,
        'depart': _departSelectionnee,
        'arret': _arretSelectionnee,
        'typeAbonnement': _typeAbonnement,
        'prix': _calculerPrixTotal(),
        'dateOperation': dateOperation,
        'dateFinAbonnement': dateExpiration,
        'userId': userId,
        'cin': _cinController.text,
        'adresse': _adressController.text,
        'nomPrenomParents': _nomPrenomParentsController.text,
      };

      try {
        await _firestore.collection('abonnements').add(donnees);

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

  String _maskCardNumber(String cardNumber) {
    if (cardNumber.length < 8) return cardNumber;
    return cardNumber.replaceRange(
        4, cardNumber.length - 4, '*' * (cardNumber.length - 8));
  }

  void _avancerEtape() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _etapeActuelle = 1;
      });
    }
  }

  void _revenirEtape() {
    setState(() {
      _etapeActuelle = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonnement de Transport'),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _etapeActuelle >= 0
                            ? const Color(0xFF0E2A47)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _etapeActuelle >= 1
                            ? const Color(0xFF0E2A47)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _etapeActuelle == 0
                  ? 'Détails de l\'abonnement'
                  : 'Informations de paiement',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0E2A47),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_etapeActuelle == 0) ...[
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
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
                          color: Color(0xFF0E2A47),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nomController,
                        decoration: InputDecoration(
                          labelText: 'Nom',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.person),
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
                        decoration: InputDecoration(
                          labelText: 'Cin',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.card_membership),
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
                        controller: _adressController,
                        decoration: InputDecoration(
                          labelText: 'Adresse',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.add_location_alt),
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
                        controller: _nomPrenomParentsController,
                        decoration: InputDecoration(
                          labelText: 'Nom et prenom parents',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre nom';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _dateNaissanceController,
                            decoration: InputDecoration(
                              labelText: 'Date de naissance',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer votre date de naissance';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _classeController,
                        decoration: InputDecoration(
                          labelText: 'Classe (pour étudiants)',
                          hintText: 'Ex: Lycée, Université, etc.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.school),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Détails de l\'abonnement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E2A47),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Ligne de bus',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.directions_bus),
                        ),
                        hint: const Text('Sélectionner une ligne'),
                        value: _ligneSelectionnee,
                        items: _lignes.map((ligne) {
                          return DropdownMenuItem<String>(
                            value: ligne['id'],
                            child: Text(ligne['Linename']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          _mettreAJourInfosLigne(value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez sélectionner une ligne';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_departSelectionnee != null &&
                          _departSelectionnee!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Départ',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _departSelectionnee ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Arrivée',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _arretSelectionnee ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Type d\'abonnement',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.credit_card),
                        ),
                        value: _typeAbonnement,
                        items: _typesAbonnement.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          _mettreAJourTypeAbonnement(value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez sélectionner un type d\'abonnement';
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
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Récapitulatif du prix',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E2A47),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Prix de l\'abonnement:',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${_calculerPrixTotal().toStringAsFixed(2)} DT',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
              ElevatedButton(
                onPressed: _avancerEtape,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E2A47),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Continuer vers le paiement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            if (_etapeActuelle == 1) ...[
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informations de paiement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E2A47),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _numeroCarteController,
                        decoration: InputDecoration(
                          labelText: 'Numéro de carte',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.credit_card),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer votre numéro de carte';
                          }
                          if (value.length < 16) {
                            return 'Le numéro de carte doit comporter 16 chiffres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dateExpirationController,
                              decoration: InputDecoration(
                                labelText: 'Date d\'expiration (MM/YY)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                                _DateExpirationInputFormatter(),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Requis';
                                }
                                if (value.length < 5) {
                                  return 'Format invalide';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _cvcController,
                              decoration: InputDecoration(
                                labelText: 'CVC',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
                                if (value.length < 3) {
                                  return 'Doit avoir 3 chiffres';
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
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Résumé de l\'abonnement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E2A47),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nom complet
                      _infoRow(
                        'Nom complet',
                        '${_prenomController.text} ${_nomController.text}',
                      ),

                      // Ligne
                      _infoRow(
                        'Ligne',
                        (() {
                          final ligne = _lignes.firstWhere(
                            (element) => element['id'] == _ligneSelectionnee,
                            orElse: () => {
                              'depart': 'Inconnu',
                              'arret': 'Inconnu',
                              'Linename': 'Inconnu'
                            },
                          );
                          return ligne['Linename'];
                        })(),
                      ),

                      // Type d'abonnement
                      _infoRow('Type', _typeAbonnement),

                      // Trajet
                      _infoRow('Trajet',
                          '${_departSelectionnee ?? ''} - ${_arretSelectionnee ?? ''}'),

                      const Divider(height: 32),

                      // Prix total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total à payer:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_calculerPrixTotal().toStringAsFixed(2)} DT',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
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
              Row(
                children: [
                  // Bouton retour
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _revenirEtape,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFF0E2A47)),
                      ),
                      child: const Text(
                        'Retour',
                        style: TextStyle(
                          color: Color(0xFF0E2A47),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Bouton payer
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _paiementEnCours ? null : _simulerPaiement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E2A47),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _paiementEnCours
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'Payer maintenant',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
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
          // En-tête du résultat
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E2A47), Color(0xFF1B4F8C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Paiement effectué avec succès !',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Votre abonnement ${_resultats['typeAbonnement']} est maintenant actif',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Détails du reçu
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
                    'Détails de l\'abonnement',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0E2A47),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Informations du client
                  _infoRow(
                      'Nom', '${_resultats['prenom']} ${_resultats['nom']}'),
                  _infoRow(
                      'Date de naissance', _resultats['dateNaissance'] ?? ''),
                  _infoRow('Classe', _resultats['classe'] ?? '-'),
                  const Divider(height: 24),

                  // Informations de l'abonnement
                  _infoRow(
                      'Type d\'abonnement', _resultats['typeAbonnement'] ?? ''),
                  _infoRow('Ligne', _resultats['ligne'] ?? ''),
                  _infoRow('Trajet',
                      '${_resultats['depart'] ?? ''} - ${_resultats['arret'] ?? ''}'),
                  _infoRow('Date d\'achat', _resultats['dateOperation'] ?? ''),
                  _infoRow('Valable jusqu\'au',
                      _resultats['dateFinAbonnement'] ?? ''),
                  const Divider(height: 24),

                  // Prix
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total payé:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_resultats['prix']?.toStringAsFixed(2) ?? '0.00'} DT',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _telechargerRecu,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E2A47),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    'Télécharger',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _partagerRecu,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: const BorderSide(color: Color(0xFF0E2A47)),
                  ),
                  icon: const Icon(Icons.share, color: Color(0xFF0E2A47)),
                  label: const Text(
                    'Partager',
                    style: TextStyle(color: Color(0xFF0E2A47)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: const BorderSide(color: Color(0xFF0E2A47)),
            ),
            icon: const Icon(Icons.history, color: Color(0xFF0E2A47)),
            label: const Text(
              'Voir l\'historique des abonnements',
              style: TextStyle(color: Color(0xFF0E2A47)),
            ),
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
                color: Color(0xFF555555),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _telechargerRecu() {
    _simulerTelechargement();
  }

  void _partagerRecu() {
    final String messageText = """
REÇU D'ABONNEMENT - BUS TRACKER
N° ${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 13)}
Date: ${_resultats['dateOperation']}

Client: ${_resultats['prenom']} ${_resultats['nom']}
Type d'abonnement: ${_resultats['typeAbonnement']}
Ligne: ${_resultats['ligne']}
Trajet: ${_resultats['depart']} - ${_resultats['arret']}
Valable jusqu'au: ${_resultats['dateFinAbonnement']}
TOTAL: ${_resultats['prix'].toStringAsFixed(2)} DT

Merci d'avoir choisi Bus Tracker pour vos déplacements!
    """;

    print(messageText);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reçu partagé avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _simulerTelechargement() {
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
              SizedBox(height: 20),
              Text('Téléchargement du reçu...'),
            ],
          ),
        ),
      ),
    );

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

// Classe pour formatter la date d'expiration de la carte
class _DateExpirationInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) return newValue;

    String formattedText = text;
    if (text.length > 2 && !text.contains('/')) {
      formattedText = '${text.substring(0, 2)}/${text.substring(2)}';
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
