import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _leaderboardData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final data = await _apiService.getLeaderboard();
      setState(() {
        _leaderboardData = data;
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
        title: const Text('Papan Peringkat', style: TextStyle(color: Color(0xFF222B45), fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3366FF)))
          : RefreshIndicator(
              onRefresh: _fetchLeaderboard,
              color: const Color(0xFF3366FF),
              // PERBAIKAN: Menggunakan ListView agar bisa di-scroll tanpa error
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_leaderboardData.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(child: Text('Belum ada data pemain.', style: TextStyle(color: Colors.grey))),
                    )
                  else ...[
                    const SizedBox(height: 16),
                    if (_leaderboardData.length >= 3) _buildPodiumSection(),
                    const SizedBox(height: 24),
                    _buildListSection(),
                  ]
                ],
              ),
            ),
    );
  }

  // --- WIDGET 1: PODIUM KHUSUS TOP 3 ---
  Widget _buildPodiumSection() {
    final top1 = _leaderboardData[0];
    final top2 = _leaderboardData[1];
    final top3 = _leaderboardData[2];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Juara 2 (Kiri)
          _buildPodiumUser(user: top2, rank: 2, avatarRadius: 32, badgeColor: const Color(0xFFC0C0C0), icon: Icons.looks_two_rounded),
          // Juara 1 (Tengah - Lebih Tinggi)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildPodiumUser(user: top1, rank: 1, avatarRadius: 42, badgeColor: const Color(0xFFFFD700), icon: Icons.emoji_events_rounded),
          ),
          // Juara 3 (Kanan)
          _buildPodiumUser(user: top3, rank: 3, avatarRadius: 28, badgeColor: const Color(0xFFCD7F32), icon: Icons.looks_3_rounded),
        ],
      ),
    );
  }

  Widget _buildPodiumUser({required Map<String, dynamic> user, required int rank, required double avatarRadius, required Color badgeColor, required IconData icon}) {
    return Column(
      children: [
        Icon(icon, color: badgeColor, size: rank == 1 ? 36 : 28),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: badgeColor, width: 2)),
          child: CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Colors.white,
            child: Text(
              user['name']?.substring(0, 1).toUpperCase() ?? 'U', 
              style: TextStyle(fontSize: avatarRadius * 0.8, fontWeight: FontWeight.bold, color: const Color(0xFF3366FF))
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user['name'] ?? '', 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222B45), fontSize: 14)
        ),
        const SizedBox(height: 4),
        Text('${user['current_xp'] ?? 0} XP', style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor, fontSize: 13)),
      ],
    );
  }

  // --- WIDGET 2: LIST BARIS PERINGKAT 4 KE BAWAH ---
  Widget _buildListSection() {
    final startIndex = _leaderboardData.length >= 3 ? 3 : 0;
    
    // Jika tidak ada sisa data untuk ditampilkan di bawah podium, hentikan
    if (_leaderboardData.length <= startIndex) return const SizedBox();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      // PERBAIKAN: Membatasi tinggi ListView di dalam ListView utama
      child: ListView.separated(
        shrinkWrap: true, // WAJIB ADA agar tidak bentrok dengan ListView di luarnya
        physics: const NeverScrollableScrollPhysics(), // Matikan scroll inner, biarkan parent yang scroll
        padding: const EdgeInsets.all(24),
        itemCount: _leaderboardData.length - startIndex,
        separatorBuilder: (context, index) => const Divider(color: Color(0xFFEDF1F7), height: 24),
        itemBuilder: (context, index) {
          final actualIndex = index + startIndex;
          final user = _leaderboardData[actualIndex];
          final rankNumber = actualIndex + 1;
          
          final levelName = user['level'] != null ? user['level']['level_name'] : '1';

          return Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '$rankNumber',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8F9BB3)),
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFF5F7FA),
                child: Text(
                  user['name']?.substring(0, 1).toUpperCase() ?? 'U', 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3366FF))
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
                    const SizedBox(height: 2),
                    Text('Level $levelName', style: const TextStyle(fontSize: 12, color: Color(0xFF8F9BB3), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text(
                '${user['current_xp'] ?? 0} XP',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF3366FF)),
              ),
            ],
          );
        },
      ),
    );
  }
}