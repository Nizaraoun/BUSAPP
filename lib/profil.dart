import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  String errorMessage = "";
  Map<String, dynamic> userData = {};
  bool isEditing = false;

  // Contrôleurs pour les champs de texte lors de la modification
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      // Vous aurez normalement besoin de récupérer l'ID utilisateur actuel
      // Cet exemple suppose que vous avez un utilisateur courant avec ID "currentUserId"
      // Dans une application réelle, vous obtiendrez cet ID via l'authentification Firebase
      String currentUserId = "currentUserId";

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      if (userDoc.exists) {
        setState(() {
          userData = userDoc.data() as Map<String, dynamic>;
          isLoading = false;

          // Initialiser les contrôleurs avec les données actuelles
          _nameController.text = userData['nomcomplet'] ?? "";
          _emailController.text = userData['email'] ?? "";
          _phoneController.text = userData['telephone'] ?? "";
        });
      } else {
        setState(() {
          errorMessage = "Utilisateur non trouvé";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Erreur lors de la récupération des données: $e";
        isLoading = false;
      });
      print("Erreur: $e");
    }
  }

  Future<void> saveUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      String currentUserId = "currentUserId";

      await _firestore.collection('users').doc(currentUserId).update({
        'nomcomplet': _nameController.text,
        'email': _emailController.text,
        'telephone': _phoneController.text,
      });

      // Mettre à jour les données locales
      setState(() {
        userData['nomcomplet'] = _nameController.text;
        userData['email'] = _emailController.text;
        userData['telephone'] = _phoneController.text;
        isEditing = false;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil mis à jour avec succès")),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la mise à jour: $e")),
      );
      print("Erreur de mise à jour: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E2A47),
        elevation: 0,
        title: const Text(
          'Mon Profil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isEditing ? Icons.save : Icons.edit,
              color: Colors.white,
            ),
            onPressed: () {
              if (isEditing) {
                saveUserData();
              } else {
                setState(() {
                  isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _buildProfileContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: fetchUserData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E2A47),
              foregroundColor: Colors.white,
            ),
            child: const Text("Réessayer"),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return RefreshIndicator(
      onRefresh: fetchUserData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 30),
            _buildProfileDetails(),
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isEditing = false;
                          // Réinitialiser les contrôleurs avec les données actuelles
                          _nameController.text = userData['nomcomplet'] ?? "";
                          _emailController.text = userData['email'] ?? "";
                          _phoneController.text = userData['telephone'] ?? "";
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                      ),
                      child: const Text("Annuler"),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: saveUserData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E2A47),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Enregistrer"),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: const Color(0xFFD0E0F5),
          child: Text(
            _getInitials(userData['nomcomplet'] ?? ""),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0E2A47),
            ),
          ),
        ),
        const SizedBox(height: 16),
        isEditing
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTextField(
                  controller: _nameController,
                  label: "Nom complet",
                  icon: Icons.person,
                ),
              )
            : Text(
                userData['nomcomplet'] ?? "Nom d'utilisateur",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0E2A47),
                ),
              ),
        const SizedBox(height: 8),
        isEditing
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTextField(
                  controller: _emailController,
                  label: "Email",
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
              )
            : Text(
                userData['email'] ?? "email@exemple.com",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
      ],
    );
  }

  Widget _buildProfileDetails() {
    if (isEditing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _buildTextField(
          controller: _phoneController,
          label: "Téléphone",
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9FF),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(color: const Color(0xFFD0E0F5)),
        ),
        child: Column(
          children: [
            _buildInfoTile(
              title: "Email",
              value: userData['email'] ?? "Non renseigné",
              icon: Icons.email,
            ),
            const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
            _buildInfoTile(
              title: "Téléphone",
              value: userData['telephone'] ?? "Non renseigné",
              icon: Icons.phone,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0E0F5)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0E2A47)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2A47).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF0E2A47),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0E2A47),
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    if (fullName.isEmpty) return "";

    List<String> names = fullName.split(" ");
    String initials = "";

    for (var name in names) {
      if (name.isNotEmpty) {
        initials += name[0].toUpperCase();
        if (initials.length >= 2) break;
      }
    }

    return initials;
  }
}
