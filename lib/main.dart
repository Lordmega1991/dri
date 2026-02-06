// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'grade_aulas_page.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gptrgiilbdpnnftovpfs.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdwdHJnaWlsYmRwbm5mdG92cGZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0MjI0OTMsImV4cCI6MjA3NDk5ODQ5M30.VxEQNzbtkKQ4ffBpqZBiik6ctGxcZNGD0aav6YPJ9a4',
  );

  await initializeDateFormatting('pt_BR', null);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _getInitialSession();
    _setupAuthListener();
  }

  Future<void> _getInitialSession() async {
    try {
      final Session? session = supabase.auth.currentSession;
      if (session != null) {
        _currentUser = session.user;
        await _registerUserIfNotExists();
      }
    } catch (e) {
      print('Erro ao obter sessão inicial: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (!mounted) return;

      if (event == AuthChangeEvent.signedIn && session != null) {
        _currentUser = session.user;
        await _registerUserIfNotExists();
        setState(() {});
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        setState(() {});
      }
    });
  }

  Future<void> _registerUserIfNotExists() async {
    if (_currentUser == null) return;

    try {
      final existing = await supabase
          .from('users_access')
          .select()
          .eq('id', _currentUser!.id)
          .maybeSingle();

      if (existing == null) {
        final accessLevel = _determineAccessLevel(_currentUser!);
        await supabase.from('users_access').insert({
          'id': _currentUser!.id,
          'email': _currentUser!.email ?? '',
          'full_name': _currentUser!.userMetadata?['full_name'] ??
              _currentUser!.userMetadata?['name'] ??
              _currentUser!.email?.split('@').first ??
              'Usuário',
          'access_level': accessLevel,
          'allowed_pages': _getAllowedPages(accessLevel),
          'created_at': DateTime.now().toIso8601String(),
        });
        print('Registro de acesso criado para: ${_currentUser!.email}');
      } else {
        print('Usuário já registrado: ${_currentUser!.email}');
      }
    } catch (e) {
      print('Erro ao registrar usuário: $e');
    }
  }

  int _determineAccessLevel(User user) {
    final email = user.email?.toLowerCase() ?? '';
    if (email.contains('@prof.') ||
        email.contains('@professor.') ||
        email.contains('docente') ||
        _isTeacherEmail(email)) {
      return 1; // Docente
    } else {
      return 1; // Discente
    }
  }

  bool _isTeacherEmail(String email) {
    final teacherDomains = ['edu.br', 'universidade', 'faculdade'];
    return teacherDomains.any((domain) => email.contains(domain));
  }

  List<String> _getAllowedPages(int accessLevel) {
    switch (accessLevel) {
      case 1:
        return [];
      case 2:
        return [];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_currentUser == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoginPage(),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Secretaria Virtual DRI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D3250)),
        useMaterial3: true,
        fontFamily:
            'Inter', // Assumindo que o usuário possa querer uma fonte moderna, mas o padrão do Flutter já é bom.
      ),
      home: HomePageWrapper(currentUser: _currentUser!),
    );
  }
}

// 🟢 Wrapper da HomePage para passar user com null-safety
class HomePageWrapper extends StatelessWidget {
  final User currentUser;
  const HomePageWrapper({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return HomePage(
      currentUser: currentUser,
    );
  }
}
