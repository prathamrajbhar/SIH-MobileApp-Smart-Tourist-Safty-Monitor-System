import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tourist.dart';
import '../utils/logger.dart';

class SafetyTipsScreen extends StatefulWidget {
  final Tourist tourist;

  const SafetyTipsScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    AppLogger.info('🛡️ Safety Tips Screen initialized');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Safety Tips',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF0F172A)),
            onPressed: _shareSafetyTips,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0EA5E9),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0EA5E9),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Emergency'),
            Tab(text: 'Local Tips'),
            Tab(text: 'Health'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralSafetyTab(),
          _buildEmergencyTab(),
          _buildLocalTipsTab(),
          _buildHealthTab(),
        ],
      ),
    );
  }

  Widget _buildGeneralSafetyTab() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSafetyCard(
            icon: Icons.visibility,
            title: 'Stay Alert & Aware',
            tips: [
              'Keep your surroundings in view at all times',
              'Avoid using headphones in unfamiliar areas',
              'Trust your instincts - leave if something feels wrong',
              'Stay in well-lit, populated areas especially at night',
              'Avoid displaying expensive items or large amounts of cash',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.phone,
            title: 'Communication Safety',
            tips: [
              'Keep your phone charged and carry a portable charger',
              'Share your location with trusted contacts',
              'Have emergency numbers saved and easily accessible',
              'Learn basic local phrases for emergencies',
              'Keep important documents digitally backed up',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.directions_walk,
            title: 'Movement & Navigation',
            tips: [
              'Plan your routes in advance using trusted apps',
              'Use official transportation services when possible',
              'Avoid walking alone late at night',
              'Stay on main roads and avoid shortcuts through unknown areas',
              'Keep a physical map as backup to digital navigation',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.group,
            title: 'Social Safety',
            tips: [
              'Travel in groups when possible',
              'Be cautious about sharing personal information',
              'Meet new people in public, well-populated places',
              'Inform someone about your plans and expected return',
              'Be wary of unsolicited help or overly friendly strangers',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmergencyCard(
            icon: Icons.local_hospital,
            title: 'Medical Emergency',
            number: '108',
            steps: [
              'Call 108 immediately for medical emergencies',
              'Provide clear location and nature of emergency',
              'Stay calm and follow dispatcher instructions',
              'Have your medical information and insurance ready',
              'Contact your embassy if you\'re a foreign tourist',
            ],
          ),
          const SizedBox(height: 16),
          _buildEmergencyCard(
            icon: Icons.local_police,
            title: 'Police Emergency',
            number: '100',
            steps: [
              'Call 100 for police assistance',
              'Clearly state your location and the emergency',
              'Remain calm and cooperative',
              'Have your identification documents ready',
              'Ask for a police report number for reference',
            ],
          ),
          const SizedBox(height: 16),
          _buildEmergencyCard(
            icon: Icons.fire_truck,
            title: 'Fire Emergency',
            number: '101',
            steps: [
              'Call 101 for fire emergencies',
              'Evacuate immediately if safe to do so',
              'Provide exact location and nature of fire',
              'Do not use elevators during evacuation',
              'Wait for emergency services at a safe distance',
            ],
          ),
          const SizedBox(height: 16),
          _buildEmergencyCard(
            icon: Icons.support_agent,
            title: 'Tourist Helpline',
            number: '1363',
            steps: [
              'Available 24/7 for tourist assistance',
              'Multilingual support available',
              'Help with lost documents, directions, emergencies',
              'Free service for all tourists',
              'Can connect you to local authorities if needed',
            ],
          ),
          const SizedBox(height: 16),
          _buildSosSection(),
        ],
      ),
    );
  }

  Widget _buildLocalTipsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSafetyCard(
            icon: Icons.local_dining,
            title: 'Food & Water Safety',
            tips: [
              'Drink only bottled or properly boiled water',
              'Avoid street food from questionable vendors',
              'Eat hot, freshly cooked food',
              'Avoid raw vegetables and fruits you can\'t peel',
              'Check restaurant hygiene before ordering',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.local_taxi,
            title: 'Transportation Tips',
            tips: [
              'Use licensed taxis or ride-sharing apps',
              'Negotiate fares before starting the journey',
              'Keep emergency numbers of taxi services',
              'Avoid overcrowded public transport',
              'Keep your luggage secure and in sight',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.shopping_bag,
            title: 'Shopping & Markets',
            tips: [
              'Bargain respectfully in local markets',
              'Be aware of common tourist scams',
              'Keep valuables in front pockets or secure bags',
              'Count change carefully',
              'Shop from established, reputable stores',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.account_balance,
            title: 'Cultural Awareness',
            tips: [
              'Respect local customs and traditions',
              'Dress appropriately for religious sites',
              'Learn basic greeting and courtesy phrases',
              'Be respectful when taking photographs',
              'Follow local laws and regulations',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSafetyCard(
            icon: Icons.medical_services,
            title: 'Medical Preparation',
            tips: [
              'Carry a basic first-aid kit',
              'Keep prescription medications in original containers',
              'Have copies of important medical documents',
              'Know your blood type and allergies',
              'Research common health risks in the area',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.local_hospital,
            title: 'Finding Medical Help',
            tips: [
              'Locate nearest hospitals and clinics',
              'Save contact numbers of recommended doctors',
              'Understand your insurance coverage',
              'Know basic medical phrases in local language',
              'Keep embassy medical officer contact handy',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.wash,
            title: 'Hygiene & Prevention',
            tips: [
              'Wash hands frequently with soap',
              'Use hand sanitizer when soap isn\'t available',
              'Avoid touching your face with unwashed hands',
              'Use insect repellent in mosquito-prone areas',
              'Stay hydrated and get adequate rest',
            ],
          ),
          const SizedBox(height: 16),
          _buildSafetyCard(
            icon: Icons.warning,
            title: 'Health Emergencies',
            tips: [
              'Recognize symptoms of common travel illnesses',
              'Seek immediate help for severe symptoms',
              'Have travel insurance contact information ready',
              'Know location of nearest 24-hour pharmacy',
              'Contact tourist helpline for medical assistance',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard({
    required IconData icon,
    required String title,
    required List<String> tips,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF0EA5E9),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0EA5E9),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard({
    required IconData icon,
    required String title,
    required String number,
    required List<String> steps,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Call $number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _callEmergencyNumber(number),
                icon: const Icon(
                  Icons.phone,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSosSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.crisis_alert,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Emergency SOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'In case of immediate danger, use the SOS feature to alert authorities and emergency contacts',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _activateSOS,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Access SOS Feature',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _callEmergencyNumber(String number) {
    HapticFeedback.heavyImpact();
    AppLogger.info('📞 Calling emergency number: $number');
    // In a real app, this would make a phone call
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $number...'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _activateSOS() {
    HapticFeedback.heavyImpact();
    AppLogger.info('🚨 SOS feature activated from Safety Tips');
    Navigator.pushNamed(context, '/sos');
  }

  void _shareSafetyTips() {
    AppLogger.info('📤 Sharing safety tips');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safety tips shared successfully!'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}