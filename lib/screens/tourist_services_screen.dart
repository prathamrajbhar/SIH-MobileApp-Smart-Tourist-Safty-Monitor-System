import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tourist.dart';
import '../utils/logger.dart';

class TouristServicesScreen extends StatefulWidget {
  final Tourist tourist;

  const TouristServicesScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<TouristServicesScreen> createState() => _TouristServicesScreenState();
}

class _TouristServicesScreenState extends State<TouristServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    AppLogger.info('🏥 Tourist Services Screen initialized');
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
          'Tourist Services',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF0F172A)),
            onPressed: _searchServices,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Emergency'),
            Tab(text: 'Medical'),
            Tab(text: 'Transportation'),
            Tab(text: 'Support'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEmergencyTab(),
          _buildMedicalTab(),
          _buildTransportationTab(),
          _buildSupportTab(),
        ],
      ),
    );
  }

  Widget _buildEmergencyTab() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmergencyContactCard(
            icon: Icons.local_police,
            title: 'Police Emergency',
            number: '100',
            description: '24/7 police assistance and emergency response',
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 16),
          _buildEmergencyContactCard(
            icon: Icons.local_hospital,
            title: 'Medical Emergency',
            number: '108',
            description: 'Ambulance and medical emergency services',
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          _buildEmergencyContactCard(
            icon: Icons.fire_truck,
            title: 'Fire Emergency',
            number: '101',
            description: 'Fire department and rescue services',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),
          _buildEmergencyContactCard(
            icon: Icons.support_agent,
            title: 'Tourist Helpline',
            number: '1363',
            description: 'Dedicated 24/7 tourist assistance hotline',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          _buildSOSSection(),
        ],
      ),
    );
  }

  Widget _buildMedicalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceCard(
            icon: Icons.local_hospital,
            title: 'Nearby Hospitals',
            description: 'Find hospitals and medical centers in your area',
            services: [
              'All India Institute of Medical Sciences (AIIMS)',
              'Fortis Healthcare',
              'Max Healthcare',
              'Apollo Hospitals',
              'Government Hospitals',
            ],
            onTap: () => _findNearbyServices('hospitals'),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.local_pharmacy,
            title: '24/7 Pharmacies',
            description: 'Locate pharmacies open round the clock',
            services: [
              'Apollo Pharmacy',
              'MedPlus',
              '1mg',
              'Local 24x7 Pharmacies',
              'Hospital Pharmacies',
            ],
            onTap: () => _findNearbyServices('pharmacies'),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.vaccines,
            title: 'Vaccination Centers',
            description: 'COVID-19 and travel vaccination facilities',
            services: [
              'Government Health Centers',
              'Private Hospitals',
              'Vaccination Drives',
              'Travel Clinics',
              'Airport Medical Centers',
            ],
            onTap: () => _findNearbyServices('vaccination'),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.psychology,
            title: 'Mental Health Support',
            description: 'Counseling and mental health services',
            services: [
              'KIRAN Mental Health Helpline: 1800-599-0019',
              'Vandrevala Foundation: 9999-666-555',
              'Private Counselors',
              'Hospital Psychiatry Dept.',
              'Online Therapy Platforms',
            ],
            onTap: () => _findNearbyServices('mental-health'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceCard(
            icon: Icons.local_taxi,
            title: 'Taxi & Ride Services',
            description: 'Safe and reliable transportation options',
            services: [
              'Uber - Download App',
              'Ola - Download App',
              'Rapido (Bike Taxi)',
              'Local Taxi Services',
              'Pre-paid Taxi Counters',
            ],
            onTap: () => _openTransportApp('taxi'),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.directions_bus,
            title: 'Public Transportation',
            description: 'Buses, metro, and public transport info',
            services: [
              'Delhi Metro',
              'Mumbai Local Trains',
              'City Bus Services',
              'State Transport Corp.',
              'Airport Express',
            ],
            onTap: () => _findNearbyServices('public-transport'),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.flight,
            title: 'Airport Services',
            description: 'Airport transfers and flight information',
            services: [
              'Airport Express Metro',
              'Airport Taxi Services',
              'Flight Status Updates',
              'Airport Customer Care',
              'Lost & Found Services',
            ],
            onTap: () => _findNearbyServices('airport'),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.train,
            title: 'Railway Services',
            description: 'Train bookings and railway information',
            services: [
              'Railway Inquiry: 139',
              'IRCTC App/Website',
              'Station Information',
              'Retiring Rooms',
              'Railway Police Help: 182',
            ],
            onTap: () => _openTransportApp('railway'),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceCard(
            icon: Icons.account_balance,
            title: 'Embassy & Consulates',
            description: 'Foreign embassy and consulate services',
            services: [
              'US Embassy: +91-11-2419-8000',
              'UK Embassy: +91-11-2419-2100',
              'Canadian Embassy: +91-11-4178-2000',
              'Australian Embassy: +91-11-4139-9900',
              'German Embassy: +91-11-4419-9199',
            ],
            onTap: () => _findNearbyServices('embassy'),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.account_balance_wallet,
            title: 'Banking & ATM',
            description: 'Banks, ATMs, and currency exchange',
            services: [
              'State Bank of India',
              'HDFC Bank',
              'ICICI Bank',
              'ATM Locators',
              'Currency Exchange Centers',
            ],
            onTap: () => _findNearbyServices('banking'),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.wifi,
            title: 'Internet & Communication',
            description: 'WiFi spots and telecom services',
            services: [
              'Free WiFi Zones',
              'Internet Cafes',
              'Mobile Recharge',
              'International Calling',
              'SIM Card Services',
            ],
            onTap: () => _findNearbyServices('internet'),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.language,
            title: 'Translation Services',
            description: 'Language support and translation help',
            services: [
              'Google Translate App',
              'Microsoft Translator',
              'Local Language Guides',
              'Tourist Information Centers',
              'Embassy Translation Services',
            ],
            onTap: () => _openTranslationServices(),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            icon: Icons.info,
            title: 'Tourist Information',
            description: 'Tourism offices and information centers',
            services: [
              'India Tourism Offices',
              'State Tourism Centers',
              'Airport Information Desks',
              'Hotel Concierge Services',
              'Local Tour Guides',
            ],
            onTap: () => _findNearbyServices('tourism-info'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactCard({
    required IconData icon,
    required String title,
    required String number,
    required String description,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
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
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: () => _callNumber(number),
                    icon: Icon(
                      Icons.phone,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String description,
    required List<String> services,
    required VoidCallback onTap,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF10B981),
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
                          Text(
                            description,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...services.take(3).map((service) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              service,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                if (services.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${services.length - 3} more services',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w500,
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

  Widget _buildSOSSection() {
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
            'In immediate danger? Activate SOS to alert authorities and emergency contacts instantly',
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
              'Activate SOS',
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

  void _callNumber(String number) {
    HapticFeedback.heavyImpact();
    AppLogger.info('📞 Calling: $number');
    // In a real app, this would make a phone call
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $number...'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _findNearbyServices(String serviceType) {
    HapticFeedback.lightImpact();
    AppLogger.info('🔍 Finding nearby services: $serviceType');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Finding nearby ${serviceType.replaceAll('-', ' ')}...'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openTransportApp(String type) {
    HapticFeedback.lightImpact();
    AppLogger.info('🚗 Opening transport app: $type');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $type services...'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openTranslationServices() {
    HapticFeedback.lightImpact();
    AppLogger.info('🌐 Opening translation services');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening translation services...'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _searchServices() {
    HapticFeedback.lightImpact();
    AppLogger.info('🔍 Searching services');
    showSearch(
      context: context,
      delegate: ServiceSearchDelegate(),
    );
  }

  void _activateSOS() {
    HapticFeedback.heavyImpact();
    AppLogger.info('🚨 SOS activated from Tourist Services');
    Navigator.pushNamed(context, '/sos');
  }
}

class ServiceSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return const Center(
      child: Text('Search results would appear here'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = [
      'Hospital',
      'Police Station',
      'Pharmacy',
      'Embassy',
      'ATM',
      'Taxi',
      'Metro Station',
      'Tourist Information',
    ];

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.search),
          title: Text(suggestions[index]),
          onTap: () {
            query = suggestions[index];
            showResults(context);
          },
        );
      },
    );
  }
}