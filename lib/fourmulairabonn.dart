import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Formulaire d\'Abonnement',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const FormulaireAbonnement(),
    );
  }
}

class FormulaireAbonnement extends StatefulWidget {
  const FormulaireAbonnement({Key? key}) : super(key: key);

  @override
  _FormulaireAbonnementState createState() => _FormulaireAbonnementState();
}

class _FormulaireAbonnementState extends State<FormulaireAbonnement> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomPrenomController = TextEditingController();
  final TextEditingController _dateNaissanceController =
      TextEditingController();
  final TextEditingController _cinController = TextEditingController();
  final TextEditingController _nomPrenomParentController =
      TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _zoneController = TextEditingController();
  final TextEditingController _villeController = TextEditingController();
  final TextEditingController _codePostalController = TextEditingController();
  final TextEditingController _ligneDeController = TextEditingController();
  final TextEditingController _ligneJusquaController = TextEditingController();

  String _statut = 'Étudiant';
  bool _transportJoursFeries = false;
  bool _isLoading = false;
  Map<String, dynamic>? _soumissionData;

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _dateNaissanceController.text =
            DateFormat('dd/MM/yyyy').format(pickedDate);
      });
    }
  }

  Future<void> _soumettreFormulaire() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Préparer les données
        final donnees = {
          'nomPrenom': _nomPrenomController.text,
          'dateNaissance': _dateNaissanceController.text,
          'cin': _cinController.text,
          'nomPrenomParent': _nomPrenomParentController.text,
          'adresse': _adresseController.text,
          'zone': _zoneController.text,
          'ville': _villeController.text,
          'codePostal': _codePostalController.text,
          'statut': _statut,
          'transportJoursFeries': _transportJoursFeries,
          'ligneDe': _ligneDeController.text,
          'ligneJusqua': _ligneJusquaController.text,
          'dateCreation': DateTime.now().toIso8601String(),
        };

        // Enregistrer dans Firebase
        final DatabaseReference ref =
            _database.ref().child('abonnements').push();
        await ref.set(donnees);

        // Afficher un message de réussite
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre abonnement a été soumis avec succès!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Afficher les données soumises
        if (mounted) {
          setState(() {
            _soumissionData = Map<String, dynamic>.from(donnees);
            _isLoading = false;
          });

          // Debug: vérifier si _soumissionData est correctement défini
          print("Données soumises: $_soumissionData");
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la soumission: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        print("Erreur: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: vérifier l'état actuel
    print("État actuel: _soumissionData=${_soumissionData != null}");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulaire d\'Abonnement'),
        backgroundColor: const Color(0xFF0E2A47),
        foregroundColor: Colors.white,
      ),
      body: _soumissionData != null
          ? _afficherRecapitulatif()
          : _construireFormulaire(),
    );
  }

  Widget _construireFormulaire() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _nomPrenomController,
              decoration: const InputDecoration(
                labelText: 'Nom et Prénom',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir votre nom et prénom';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateNaissanceController,
              decoration: InputDecoration(
                labelText: 'Date de naissance',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ),
              readOnly: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez sélectionner votre date de naissance';
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
            TextFormField(
              controller: _nomPrenomParentController,
              decoration: const InputDecoration(
                labelText: 'Nom et Prénom du parent',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir le nom et prénom du parent';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adresseController,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir votre adresse';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _zoneController,
                    decoration: const InputDecoration(
                      labelText: 'Zone',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obligatoire';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _villeController,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obligatoire';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codePostalController,
              decoration: const InputDecoration(
                labelText: 'Code Postal',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir votre code postal';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _statut,
              decoration: const InputDecoration(
                labelText: 'Statut',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Étudiant', child: Text('Étudiant')),
                DropdownMenuItem(value: 'Étudiante', child: Text('Étudiante')),
              ],
              onChanged: (value) {
                setState(() {
                  _statut = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez sélectionner votre statut';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Transport les dimanches et jours fériés'),
              value: _transportJoursFeries,
              onChanged: (bool value) {
                setState(() {
                  _transportJoursFeries = value;
                });
              },
              subtitle: Text(_transportJoursFeries ? 'Oui' : 'Non'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ligneDeController,
                    decoration: const InputDecoration(
                      labelText: 'Ligne de',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obligatoire';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _ligneJusquaController,
                    decoration: const InputDecoration(
                      labelText: 'jusqu\'à',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Obligatoire';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NB:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Veuillez apporter un document prouvant votre appartenance à cet établissement lors de la soumission de l\'abonnement . Tout contrevenant sera interdit de participation jusqu\'à ce qu\'il apporte le document.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _soumettreFormulaire,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E2A47),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('PAYER',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _afficherRecapitulatif() {
    // Vérification de sécurité pour éviter les erreurs null
    if (_soumissionData == null) {
      // Si pour une raison quelconque _soumissionData est null, on retourne au formulaire
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _soumissionData = null;
        });
      });
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade700),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 50,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paiement réussi!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Votre abonnement a été enregistré avec succès',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Récapitulatif de votre abonnement',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _infoItem(
              'Nom et prénom', _soumissionData!['nomPrenom'] ?? 'Non spécifié'),
          _infoItem('Date de naissance',
              _soumissionData!['dateNaissance'] ?? 'Non spécifié'),
          _infoItem('CIN', _soumissionData!['cin'] ?? 'Non spécifié'),
          _infoItem('Nom et prénom du parent',
              _soumissionData!['nomPrenomParent'] ?? 'Non spécifié'),
          _infoItem('Adresse',
              '${_soumissionData!['adresse'] ?? ''}, ${_soumissionData!['zone'] ?? ''}, ${_soumissionData!['ville'] ?? ''}'),
          _infoItem(
              'Code postal', _soumissionData!['codePostal'] ?? 'Non spécifié'),
          _infoItem('Statut', _soumissionData!['statut'] ?? 'Non spécifié'),
          _infoItem(
              'Transport les dimanches et jours fériés',
              (_soumissionData!['transportJoursFeries'] == true)
                  ? 'Oui'
                  : 'Non'),
          _infoItem('Ligne demandée',
              'De ${_soumissionData!['ligneDe'] ?? ''} jusqu\'à ${_soumissionData!['ligneJusqua'] ?? ''}'),
          const SizedBox(height: 32),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Imprimer'),
                  onPressed: () {
                    // Fonctionnalité d'impression à implémenter si nécessaire
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Impression en cours...'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _soumissionData = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E2A47),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retour au formulaire'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
