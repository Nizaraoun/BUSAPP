import 'package:flutter/material.dart';
import 'package:flutter_application_1/fourmulairabonn.dart';
import 'package:flutter_application_1/fourmulairetick.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({Key? key}) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedOption = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: const Color(0xFF0E2A47),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // En-tête
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF0E2A47),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choisissez votre mode de paiement',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Sélectionnez une option ci-dessous',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Options de paiement
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Option Tickets
                  PaymentOptionCard(
                    title: 'Tickets',
                    description: 'Achetez des tickets individuels ou en carnet',
                    icon: Icons.confirmation_number,
                    isSelected: _selectedOption == 'tickets',
                    onTap: () {
                      setState(() {
                        _selectedOption = 'tickets';
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Option Abonnement
                  PaymentOptionCard(
                    title: 'Abonnement',
                    description:
                        'Souscrivez à un abonnement Trimestriel ou semestrielle',
                    icon: Icons.card_membership,
                    isSelected: _selectedOption == 'abonnement',
                    onTap: () {
                      setState(() {
                        _selectedOption = 'abonnement';
                      });
                    },
                  ),

                  const Spacer(),

                  // Bouton de continuation
                  ElevatedButton(
                    onPressed: _selectedOption.isEmpty
                        ? null
                        : () {
                            // Navigation vers la page suivante selon l'option sélectionnée
                            if (_selectedOption == 'tickets') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FormulaireTicket(
                                    title: '',
                                  ),
                                ),
                              );
                            } else {
                              // Navigation vers le formulaire d'abonnement
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const FormulaireAbonnement(),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E2A47),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: const Text(
                      'Continuer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0E2A47) : Colors.grey.shade300,
            width: 2,
          ),
          color: isSelected
              ? const Color(0xFF0E2A47).withOpacity(0.05)
              : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF0E2A47) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? const Color(0xFF0E2A47) : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF0E2A47).withOpacity(0.8)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color:
                  isSelected ? const Color(0xFF0E2A47) : Colors.grey.shade400,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
