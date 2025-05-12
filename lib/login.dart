import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/acceuil.dart';
import 'package:flutter_application_1/authentication.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError("Veuillez remplir tous les champs");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      debugPrint("Connexion réussie !");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AccueilPage()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Erreur de connexion");
    } catch (e) {
      _showError("Une erreur est survenue");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Bienvenue 👋',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0E2A47),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connectez-vous pour continuer',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Adresse Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Add forgot password logic here
                  },
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'Se connecter',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Pas encore de compte ? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const AuthentificationPage()));
                    },
                    child: const Text(
                      "S'inscrire",
                      style: TextStyle(
                        color: Color(0xFF1E88E5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
