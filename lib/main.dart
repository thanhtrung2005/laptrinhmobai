import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Thêm thư viện Auth
import 'firebase_options.dart';

// Import các màn hình của bạn (Chú ý: Nếu đường dẫn thư mục của bạn khác, hãy sửa lại cho đúng nhé)
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase an toàn cho Web
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mạng xã hội Hiến máu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      
      // Kiểm tra trạng thái đăng nhập liên tục (Real-time)
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Nếu đang chờ tải dữ liệu kiểm tra từ Firebase
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.red)),
            );
          }
          
          // 2. Nếu đã đăng nhập thành công (có dữ liệu user)
          if (snapshot.hasData) {
            return const MainScreen();
          }
          
          // 3. Nếu chưa đăng nhập hoặc đã đăng xuất
          return const LoginScreen();
        },
      ),
    );
  }
}