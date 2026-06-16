// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/subject_provider.dart';
import 'providers/student_provider.dart';
import 'providers/question_provider.dart';
import 'providers/result_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/auth_repository_impl.dart';
import 'repositories/subject_repository.dart';
import 'repositories/subject_repository_impl.dart';
import 'repositories/student_repository.dart';
import 'repositories/student_repository_impl.dart';
import 'repositories/question_repository.dart';
import 'repositories/question_repository_impl.dart';
import 'repositories/result_repository.dart';
import 'repositories/result_repository_impl.dart';
import 'services/auth_service.dart';
import 'services/subject_service.dart';
import 'services/student_service.dart';
import 'services/question_service.dart';
import 'services/result_service.dart';
import 'models/user.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _seedTestUsers();
  runApp(const EstudioApp());
}

Future<void> _seedTestUsers() async {
  final auth = fb.FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

try {
  final usersSnapshot =
      await firestore.collection('users').limit(1).get();
  if (usersSnapshot.docs.isNotEmpty) return;
} on FirebaseException catch (e) {
  if (e.code == 'permission-denied') {
    return;
  } 
  return; // Otro error, no hacer nada
  
}

  final testUsers = [
    {
      'email': 'admin@escuela.com',
      'password': 'admin123',
      'name': 'Administrador Principal',
      'role': 'admin',
    },
    {
      'email': 'padre@familia.com',
      'password': 'padre123',
      'name': 'Juan Pérez',
      'role': 'parent',
    },
    {
      'email': 'estudiante@escuela.com',
      'password': 'estudiante123',
      'name': 'María Pérez',
      'role': 'student',
    },
  ];

  String? parentUid;

  for (final userData in testUsers) {
    try {
      fb.UserCredential credential;
      try {
        credential = await auth.createUserWithEmailAndPassword(
          email: userData['email']!,
          password: userData['password']!,
        );
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          credential = await auth.signInWithEmailAndPassword(
            email: userData['email']!,
            password: userData['password']!,
          );
        } else {
          continue;
        }
      }

      final uid = credential.user!.uid;
      if (userData['role'] == 'parent') parentUid = uid;

      final user = User(
        id: uid,
        email: userData['email']!,
        name: userData['name']!,
        role: UserRole.values.firstWhere(
          (r) => r.toString().split('.').last == userData['role'],
        ),
        createdAt: DateTime.now(),
        isActive: true,
        parentId:
            userData['role'] == 'student' ? parentUid : null,
        assignedSubjects: userData['role'] == 'student'
            ? ['math_001', 'science_001']
            : [],
      );

      await firestore.collection('users').doc(uid).set(user.toJson());
    } catch (e) {
      debugPrint('Error seeding user: $e');
    }
  }

  await auth.signOut();
}

class EstudioApp extends StatelessWidget {
  const EstudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final authRepository =
        AuthRepositoryImpl(authService: authService);
    final subjectService = SubjectService();
    final subjectRepository =
        SubjectRepositoryImpl(subjectService: subjectService);
    final studentService = StudentService();
    final studentRepository =
        StudentRepositoryImpl(studentService: studentService);
    final questionService = QuestionService();
    final questionRepository =
        QuestionRepositoryImpl(questionService: questionService);
    final resultService = ResultService();
    final resultRepository =
        ResultRepositoryImpl(resultService: resultService);

    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<SubjectService>.value(value: subjectService),
        Provider<StudentService>.value(value: studentService),
        Provider<QuestionService>.value(value: questionService),
        Provider<ResultService>.value(value: resultService),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<SubjectRepository>.value(value: subjectRepository),
        Provider<StudentRepository>.value(value: studentRepository),
        Provider<QuestionRepository>.value(value: questionRepository),
        Provider<ResultRepository>.value(value: resultRepository),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) =>
              AuthProvider(authRepository: authRepository),
        ),
        ChangeNotifierProvider<SubjectProvider>(
          create: (_) =>
              SubjectProvider(subjectRepository: subjectRepository),
        ),
        ChangeNotifierProvider<StudentProvider>(
          create: (_) =>
              StudentProvider(studentRepository: studentRepository),
        ),
        ChangeNotifierProvider<QuestionProvider>(
          create: (_) =>
              QuestionProvider(questionRepository: questionRepository),
        ),
        ChangeNotifierProvider<ResultProvider>(
          create: (_) =>
              ResultProvider(resultRepository: resultRepository),
        ),
      ],
      child: MaterialApp(
        title: 'EstudioApp',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        switch (authProvider.status) {
          case AuthStatus.loading:
            return const LoadingScreen();
          case AuthStatus.authenticated:
            return const HomeScreen();
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            return const LoginScreen();
        }
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text('EstudioApp',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    )),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.blue[600]!),
            ),
            const SizedBox(height: 16),
            Text('Cargando...',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}