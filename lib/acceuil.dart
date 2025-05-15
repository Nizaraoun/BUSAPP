import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/authentication.dart';
import 'package:flutter_application_1/chatbot.dart';
import 'package:flutter_application_1/historique_abonnements.dart';
import 'package:flutter_application_1/historique_tickets.dart';
import 'package:flutter_application_1/login.dart';
import 'package:flutter_application_1/map.dart';
import 'package:flutter_application_1/paiement.dart';
import 'package:flutter_application_1/profil.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage>
    with SingleTickerProviderStateMixin {
  String busCode = "";
  String lineName = "";
  bool isLoading = true;
  String errorMessage = "";
  int _currentCarouselIndex = 0;
  String _searchQuery = "";

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot>? busStream;

  late AnimationController _chatbotAnimationController;
  late Animation<double> _chatbotAnimation;

  // Weather data (mock)
  final String _currentWeather = '☀️';
  final String _temperature = '28°C';

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
        print("Stream de bus configuré avec succès");
        print("Stream de bus: $busStream");
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
                icon: Icons.receipt_long,
                title: "Historique des tickets",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HistoriqueTickets()),
                  );
                },
              ),
              _buildMenuOption(
                icon: Icons.payment,
                title: "Historique des abonnements",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HistoriqueAbonnements()),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatPage()),
                  );
                },
              ),
              _buildMenuOption(
                icon: Icons.logout,
                title: "Deconnexion",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
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
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildHeader(),
                        ),
                        const SizedBox(height: 24),
                        _buildBusDataStream(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'Suivi Bus',
                      textStyle: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0E2A47),
                      ),
                      speed: const Duration(milliseconds: 200),
                    ),
                  ],
                  totalRepeatCount: 1,
                  displayFullTextOnTap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  'Trouvez votre bus facilement',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ).animate().fadeIn(duration: 800.ms, delay: 300.ms).slideX(),
              ],
            ),
            Row(
              children: [
                _buildWeatherWidget(),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _showMenuOptions(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0E2A47).withOpacity(0.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu,
                      color: Color(0xFF0E2A47),
                      size: 22,
                    ),
                  ),
                ).animate().scale(duration: 300.ms, delay: 200.ms),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF0E2A47)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher des lignes de bus...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0E2A47),
                  ),
                  onChanged: (value) {
                    // Filter bus lines based on search query
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Show filter options dialog
                  _showFilterOptions(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E2A47).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.tune,
                    color: Color(0xFF0E2A47),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 300.ms)
            .moveY(begin: 20, end: 0),
      ],
    );
  }

  Widget _buildWeatherWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            _currentWeather,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 4),
          Text(
            _temperature,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0E2A47),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms);
  }

  void _showFilterOptions(BuildContext context) {
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
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Filtrer les lignes de bus",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0E2A47),
                  ),
                ),
              ),
              _buildFilterOption("Toutes les lignes", true),
              _buildFilterOption("Itinéraires principaux", false),
              _buildFilterOption("Arrêts à proximité", false),
              _buildFilterOption("Moins encombrés", false),
              _buildFilterOption("Itinéraires les plus rapides", false),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Filtres appliqués")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E2A47),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Appliquer les filtres"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String title, bool isSelected) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF0E2A47) : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? const Color(0xFF0E2A47) : Colors.grey[400],
      ),
      onTap: () {
        // Handle filter selection
      },
    );
  }

  Widget _buildBusDataStream() {
    if (isLoading) {
      return _buildShimmerLoading();
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60)
                .animate()
                .shake(duration: 700.ms),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E2A47),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text("Réessayer"),
            ).animate().scale(duration: 300.ms),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: busStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoading();
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.no_transfer,
                  size: 70,
                  color: Colors.grey[400],
                ).animate().scale(duration: 500.ms),
                const SizedBox(height: 20),
                Text(
                  "Aucun bus trouvé",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 12),
                Text(
                  "Essayez de rafraîchir ou vérifiez ultérieurement",
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          );
        }

        final allDocs = snapshot.data!.docs;

        // Filter docs based on search query
        final docs = _searchQuery.isEmpty
            ? allDocs
            : allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final busCode =
                    (data['busCode'] ?? "").toString().toLowerCase();
                final lineName =
                    (data['lineName'] ?? "").toString().toLowerCase();
                return busCode.contains(_searchQuery) ||
                    lineName.contains(_searchQuery);
              }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 70,
                  color: Colors.grey[400],
                ).animate().scale(duration: 500.ms),
                const SizedBox(height: 20),
                Text(
                  "Aucun résultat pour \"$_searchQuery\"",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 12),
                Text(
                  "Essayez avec d'autres termes de recherche",
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          );
        }

        print(docs);

        return Column(
          children: [
            _buildFeaturedBusSection(docs),
            const SizedBox(height: 16),
            _buildAllBusesSection(docs),
          ],
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            height: 24,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            height: 24,
            width: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          ...List.generate(
            3,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedBusSection(List<QueryDocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Lignes principales",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0E2A47),
                ),
              ),
              Text(
                "Voir tout",
                style: TextStyle(
                  color: Color(0xFF1E88E5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CarouselSlider.builder(
          itemCount: docs.length,
          options: CarouselOptions(
            height: 220,
            viewportFraction: 0.85,
            enlargeCenterPage: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            onPageChanged: (index, reason) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
          ),
          itemBuilder: (context, index, realIndex) {
            final busData = docs[index].data() as Map<String, dynamic>;
            return _buildFeaturedBusCard(
              busCode: busData['busCode'] ?? "N/A",
              lineName: busData['lineName'] ?? "N/A",
              busId: busData['busId'] ?? "N/A",
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: docs.asMap().entries.map((entry) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentCarouselIndex == entry.key
                    ? const Color(0xFF0E2A47)
                    : Colors.grey[300],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAllBusesSection(List<QueryDocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Toutes les lignes",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0E2A47),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final busData = docs[index].data() as Map<String, dynamic>;
            return _buildBusListItem(
              busCode: busData['busCode'] ?? "N/A",
              lineName: busData['lineName'] ?? "N/A",
              busId: busData['busId'] ?? "N/A",
              index: index,
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedBusCard({
    required String busCode,
    required String lineName,
    required String busId,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2A47), Color(0xFF1E5B94)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E2A47).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.directions_bus,
              size: 120,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        "Bus $busCode",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.navigation_outlined,
                        color: Color(0xFF0E2A47),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  lineName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Prochain départ: 5 min",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.people,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Affluence: Modérée",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Bus $busId sélectionné")),
                );
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.transparent,
              child: SizedBox(
                height: double.infinity,
                width: double.infinity,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusListItem({
    required String busCode,
    required String lineName,
    required String busId,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Bus $busId sélectionné")),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F9FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Color(0xFF0E2A47),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lineName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E2A47),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Bus $busCode",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E2A47).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "7 min",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0E2A47),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: Duration(milliseconds: 100 * index));
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
          _buildInfoRow("Code de bus:", busCode, const Color(0xFF1E88E5)),
          const SizedBox(height: 8),
          _buildInfoRow("Nom de ligne:", lineName, const Color(0xFF00AA63)),
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
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home, true, "Accueil", () {
            // Reste sur la page actuelle
          }),
          _buildNavItem(Icons.receipt_long, false, "Historique", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const HistoriqueTickets()),
            );
          }),
          _buildNavItem(Icons.location_on, false, "Localisation", () {
            // Navigate to the Map page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MapScreen()),
            );
          }),
          _buildFloatingNavItem(Icons.access_time, "Horaires", () {
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
    )
        .animate()
        .slideY(begin: 50, end: 0, duration: 600.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildNavItem(
      IconData icon, bool isSelected, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF0E2A47) : Colors.grey,
                size: 24,
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Container(
                  height: 4,
                  width: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0E2A47),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavItem(
      IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0E2A47), Color(0xFF1E5B94)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E2A47).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
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
            MaterialPageRoute(builder: (context) => const ChatPage()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ScaleTransition(
            scale: _chatbotAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0E2A47).withOpacity(0.1),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.support_agent,
                  color: Color(0xFF0E2A47),
                  size: 24,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    height: 8,
                    width: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
