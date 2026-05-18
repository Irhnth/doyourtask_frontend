import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _apiService.getUserProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF222B45)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profil Pemain', style: TextStyle(color: Color(0xFF222B45), fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3366FF)))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 32),
                  _buildLevelProgressCard(),
                  const SizedBox(height: 32),
                  _buildBadgesSection(),
                ],
              ),
            ),
    );
  }

  // --- 1. WIDGET FOTO & NAMA PROFIL ---
  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF3366FF), width: 3),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Text(
              _userProfile?['name']?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF3366FF)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _userProfile?['name'] ?? 'Pemain Misterius',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF222B45), letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Text(
          _userProfile?['email'] ?? 'email@tidakditemukan.com',
          style: const TextStyle(fontSize: 14, color: Color(0xFF8F9BB3), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // --- 2. WIDGET PROGRESS BAR LEVEL ---
  Widget _buildLevelProgressCard() {
    final currentXp = _userProfile?['current_xp'] ?? 0;
    final nextLevelXp = _userProfile?['next_level_xp_required'];
    
    // Hitung persentase bar (0.0 sampai 1.0)
    double progress = 1.0; 
    if (nextLevelXp != null && nextLevelXp > 0) {
      progress = currentXp / nextLevelXp;
      if (progress > 1.0) progress = 1.0;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF8F9BB3).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech_rounded, color: Color(0xFFFFC94D), size: 28),
                  const SizedBox(width: 8),
                  Text('Level ${_userProfile?['level']?['level_name'] ?? '1'}', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
                ],
              ),
              Text('$currentXp XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3366FF), fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFEDF1F7),
              color: const Color(0xFF00E096),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              nextLevelXp != null 
                  ? 'Butuh ${nextLevelXp - currentXp} XP lagi untuk naik level!' 
                  : 'Level Maksimal Tercapai!',
              style: const TextStyle(color: Color(0xFF8F9BB3), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. WIDGET RAK LENCANA (BADGES) ---
  Widget _buildBadgesSection() {
    List<dynamic> badges = _userProfile?['badges'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Koleksi Lencana', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45), letterSpacing: -0.5)),
        const SizedBox(height: 16),
        badges.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('Belum ada lencana', style: TextStyle(color: Color(0xFF8F9BB3), fontWeight: FontWeight.w500)),
                      const Text('Selesaikan tugas untuk mendapatkannya!', style: TextStyle(color: Color(0xFF8F9BB3), fontSize: 12)),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 lencana sejajar
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final badge = badges[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEDF1F7)),
                      boxShadow: [BoxShadow(color: const Color(0xFF8F9BB3).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFFFF3D6), shape: BoxShape.circle),
                          child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFAA00), size: 32),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            badge['badge_name'] ?? 'Lencana',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF222B45)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }
}