import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Ganti URL ini sesuai dengan Forwarding URL dari Ngrok Anda
  // Contoh: 'https://1a2b-3c4d-5e.ngrok-free.app/api'
  static const String baseUrl = 'https://masculine-geriatric-headstone.ngrok-free.dev/api'; 

  // ==========================================
  // 1. FUNGSI LOGIN
  // ==========================================
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Header Anti-Blokir Ngrok
      },
      body: {
        'email': email.trim(),
        'password': password
      },
    );

    print('Status Code Login: ${response.statusCode}');
    print('Response Body Login: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      return data;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Gagal Login. Periksa kredensial.');
    }
  }

  // ==========================================
  // 2. FUNGSI REGISTER
  // ==========================================
  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Header Anti-Blokir Ngrok
      },
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password
      },
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      return data;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Gagal mendaftar.');
    }
  }

  // ==========================================
  // 3. FUNGSI SELESAIKAN TUGAS (GAMIFIKASI)
  // ==========================================
  Future<Map<String, dynamic>> completeTask(int taskId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/complete'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Header Anti-Blokir Ngrok
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal menyelesaikan tugas');
    }
  }

  // ==========================================
  // 4. FUNGSI AMBIL PROFIL USER
  // ==========================================
  Future<Map<String, dynamic>> getUserProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Header Anti-Blokir Ngrok
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal mengambil data profil');
    }
  }

  // ==========================================
  // 5. FUNGSI AMBIL DAFTAR TUGAS
  // ==========================================
  Future<List<dynamic>> getTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/tasks'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Header Anti-Blokir Ngrok
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['tasks'];
    } else {
      throw Exception('Gagal mengambil daftar tugas');
    }
  }

  // ==========================================
  // 6. FUNGSI LOGOUT
  // ==========================================
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // ==========================================
  // 7. FUNGSI TAMBAH TUGAS (BESERTA DESKRIPSI)
  // ==========================================
  Future<Map<String, dynamic>> createTask(String title, String deadline, {String description = ''}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('$baseUrl/tasks'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Header Anti-Blokir Ngrok
      },
      body: {
        'title': title,
        'deadline': deadline,
        'description': description,
      },
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal menambahkan tugas. Pastikan isian benar.');
    }
  }

  // ==========================================
  // 8. FUNGSI EDIT TUGAS (UPDATE)
  // ==========================================
  Future<Map<String, dynamic>> updateTask(int id, String title, String deadline, {String description = ''}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('$baseUrl/tasks/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Header Anti-Blokir Ngrok
      },
      body: {
        'title': title,
        'deadline': deadline,
        'description': description,
      },
    );

    // BANTUAN DEBUG: Tampilkan di terminal VS Code
    print('--- DEBUG EDIT TUGAS ---');
    print('Status Code: ${response.statusCode}');
    print('Response: ${response.body}');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      // Tampilkan pesan asli dari Laravel ke layar HP
      final errorMsg = json.decode(response.body)['message'] ?? 'Error tidak diketahui';
      throw Exception('Gagal Edit: $errorMsg');
    }
  }

  // ==========================================
  // 9. FUNGSI HAPUS TUGAS (DELETE)
  // ==========================================
  Future<void> deleteTask(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.delete(
      Uri.parse('$baseUrl/tasks/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true', // Header Anti-Blokir Ngrok
      },
    );

    // BANTUAN DEBUG: Tampilkan di terminal VS Code
    print('--- DEBUG HAPUS TUGAS ---');
    print('Status Code: ${response.statusCode}');
    print('Response: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Gagal Hapus: Status ${response.statusCode}');
    }
  }

  // ==========================================
  // 10. FUNGSI AMBIL DATA PAPAN PERINGKAT
  // ==========================================
  Future<List<dynamic>> getLeaderboard() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/leaderboard'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // PERBAIKAN: Pastikan selalu mengembalikan List meskipun kosong
      return data['leaderboard'] ?? []; 
    } else {
      throw Exception('Gagal memuat papan peringkat');
    }
  }
}