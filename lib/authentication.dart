import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/acceuil.dart';
import 'package:flutter_application_1/login.dart';

class AuthentificationPage extends StatefulWidget {
  const AuthentificationPage({Key? key}) : super(key: key);

  @override
  _AuthentificationPageState createState() => _AuthentificationPageState();
}

class _AuthentificationPageState extends State<AuthentificationPage> {
  bool _acceptTerms = false;
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Contrôleurs pour les champs de formulaire
  final TextEditingController _nomCompletController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _nomCompletController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate() && _acceptTerms) {
      try {
        // Check if the passwords match
        if (_passwordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Les mots de passe ne correspondent pas')),
          );
          return;
        }

        // 1. Créer l'utilisateur avec email/mot de passe
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Enregistrer les infos supplémentaires dans Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'nomComplet': _nomCompletController.text.trim(),
          'email': _emailController.text.trim(),
          'telephone': '+33${_phoneController.text.trim()}',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Redirection vers la page d'accueil
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AccueilPage()),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Erreur d\'inscription: ${e.message}';
        if (e.code == 'email-already-in-use') {
          errorMessage =
              'Cet email est déjà utilisé. Veuillez en choisir un autre.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Une erreur s'est produite")),
        );
      }
    } else if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vous devez accepter les conditions d\'utilisation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un compte'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nom complet
              TextFormField(
                controller: _nomCompletController,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre nom complet';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Veuillez entrer une adresse email valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Numéro de téléphone
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('+216'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de téléphone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            value.length < 9) {
                          return 'Numéro invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mot de passe
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 6) {
                    return 'Le mot de passe doit contenir au moins 6 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirmer mot de passe
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Bouton S'inscrire
              ElevatedButton(
                onPressed: _registerUser,
                child:
                    const Text('S\'inscrire', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white),
              ),
              const SizedBox(height: 16),

              // Lien de connexion
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()));
                  },
                  child: const Text(
                    'Vous avez déjà un compte ? Se connecter',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Options de connexion sociale
              const Divider(),
              const SizedBox(height: 16),
              SocialAuthButton(
                icon: Icons.g_mobiledata,
                text: 'S\'inscrire avec Google',
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              SocialAuthButton(
                icon: Icons.facebook,
                text: 'S\'inscrire avec Facebook',
                onPressed: () {},
              ),
              const SizedBox(height: 24),

              // Checkbox des conditions
              Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() {
                        _acceptTerms = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Afficher les conditions d'utilisation
                      },
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                                text: 'En vous inscrivant, vous acceptez nos '),
                            TextSpan(
                              text: 'conditions d\'utilisation',
                              style: TextStyle(color: Colors.blue),
                            ),
                            TextSpan(text: ' et notre '),
                            TextSpan(
                              text: 'politique de confidentialité',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  const SocialAuthButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: Colors.grey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }
}
