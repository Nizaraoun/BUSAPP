import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/chatbot.dart';
import 'package:flutter_application_1/paiement.dart';
import 'package:flutter_application_1/profil.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({Key? key}) : super(key: key);

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage>
    with SingleTickerProviderStateMixin {
  String busCode = "";
  String lineName = "";
  bool isLoading = true;
  String errorMessage = "";

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot>? busStream;

  late AnimationController _chatbotAnimationController;
  late Animation<double> _chatbotAnimation;

  @override
  void initState() {
    super.initState();
    setupBusStream();
    _chatbotAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _chatbotAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _chatbotAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _chatbotAnimationController.dispose();
    super.dispose();
  }

  void setupBusStream() {
    try {
      busStream = _firestore.collection('buses').snapshots();
      setState(() {
        isLoading = false;
        errorMessage = "";
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Erreur de connexion à la base de données";
        print("Erreur: $e");
      });
    }
  }

  Future<void> refreshData() async {
    setState(() {
      isLoading = true;
    });
    setupBusStream();
  }

  void _showMenuOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuOption(
                icon: Icons.settings,
                title: "Paramètres",
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Paramètres sélectionnés")),
                  );
                },
              ),
              _buildMenuOption(
                icon: Icons.person,
                title: "Profil",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfilePage()),
                  );
                },
              ),
              _buildMenuOption(
                icon: Icons.info_outline,
                title: "À propos",
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("À propos sélectionné")),
                  );
                },
              ),
              _buildMenuOption(
                icon: Icons.help_outline,
                title: "Aide",
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Aide sélectionnée")),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF0E2A47),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0E2A47),
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: refreshData,
                  child: _buildBusDataStream(),
                ),
              ),
              _buildBottomNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Bus Tracker',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0E2A47),
          ),
        ),
        Row(
          children: [
            InkWell(
              onTap: () => _showMenuOptions(context),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.menu, // Icône hamburger
                  color: Color(0xFF0E2A47),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBusDataStream() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: refreshData,
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

    return StreamBuilder<QuerySnapshot>(
      stream: busStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Erreur: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "Aucun bus trouvé",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final busData =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildBusDetailCard(
              busCode: busData['busCode'] ?? "N/A",
              lineName: busData['lineName'] ?? "N/A",
              busId: busData['busId'] ?? "N/A",
            );
          },
        );
      },
    );
  }

  Widget _buildBusDetailCard({
    required String busCode,
    required String lineName,
    required String busId,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Bus $busId sélectionné")),
              );
            },
            borderRadius: BorderRadius.circular(40),
            child: Ink(
              height: 60,
              width: 60,
              decoration: const BoxDecoration(
                color: Color(0xFF0E2A47),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_bus_rounded,
                  color: Color.fromARGB(255, 42, 12, 92), size: 35),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow("Bus Code:", busCode, const Color(0xFF1E88E5)),
          const SizedBox(height: 8),
          _buildInfoRow("Line Name:", lineName, const Color(0xFF00AA63)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, color: Color(0xFF0E2A47))),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color),
          maxLines: null,
          softWrap: true,
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, true, "Accueil", () {
            // Reste sur la page actuelle
          }),
          _buildNavItem(Icons.location_on, false, "Localisation", () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Localisation sélectionnée")),
            );
          }),
          _buildNavItem(Icons.access_time, false, "Horaires", () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Horaires sélectionnés")),
            );
          }),
          _buildNavItem(Icons.credit_card, false, "Paiement", () {
            // Navigation vers la page de paiement
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PaymentPage()),
            );
          }),
          _buildAnimatedChatbotIcon(),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, bool isSelected, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: isSelected ? const Color(0xFF0E2A47) : Colors.grey,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedChatbotIcon() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const ChatPage()), // Navigation vers ChatPage
          );
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: ScaleTransition(
            scale: _chatbotAnimation,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0E2A47).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.support_agent,
                color: Color(0xFF0E2A47),
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
