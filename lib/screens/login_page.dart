import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:repaso/screens/sign_up_page.dart';
import 'package:repaso/widgets/common_widgets/common_text_field.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../utils/app_colors.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isPasswordVisible = false;

  String email = "";
  String password = "";

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showPasswordResetDialog() {
    final TextEditingController resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          backgroundColor: Colors.white,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '以下のメールアドレスに\nパスワードリセットメールを送信します',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  CommonTextField(
                    controller: resetEmailController,
                    labelText: 'メールアドレス',
                  ),
                  const SizedBox(height: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        onPressed: () async {
                          final email = resetEmailController.text.trim();
                          if (email.isNotEmpty) {
                            await _sendPasswordResetEmail(email);
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('メールアドレスを入力してください。')),
                            );
                          }
                        },
                        child: const Text('送信する', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('キャンセル', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードリセットメールを送信しました。')),
      );
    } on FirebaseAuthException catch (e) {
      final errorMessage = e.code == 'user-not-found'
          ? 'このメールアドレスは登録されていません。'
          : 'エラーが発生しました: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('予期しないエラーが発生しました: $e')),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
      }
      await requestTrackingPermission();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
            (route) => false,
      );
    } catch (e) {
      print("Google Sign In Error: $e");
    }
  }

  Future<void> _signInWithApple() async {
    try {
      if (kIsWeb) {
        final appleProvider = OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
        await FirebaseAuth.instance.signInWithPopup(appleProvider);
      } else {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        );
        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: credential.identityToken,
          accessToken: credential.authorizationCode,
        );
        await _auth.signInWithCredential(oauthCredential);
      }
      await requestTrackingPermission();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MainPage()));
    } catch (e) {
      print('Apple Sign-In Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ログイン', style: TextStyle(color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.g_mobiledata_sharp, color: Colors.white, size: 36),
                      Text('Googleでログイン', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signInWithApple,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.apple, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text('Appleでログイン', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('または、メールアドレスでログイン'),
                    ),
                    Expanded(child: Divider(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 32),
                CommonTextField(
                  controller: _emailController,
                  labelText: 'メールアドレス',
                  onChanged: (value) => setState(() => email = value),
                ),
                const SizedBox(height: 16),
                CommonTextField(
                  controller: _passwordController,
                  labelText: 'パスワード',
                  obscureText: !_isPasswordVisible,
                  onChanged: (value) => setState(() => password = value),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showPasswordResetDialog,
                    child: const Text('パスワードを忘れた', style: TextStyle(color: AppColors.blue600)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final emailTrimmed = email.trim();
                      final passwordTrimmed = password.trim();

                      // メールアドレスの形式を事前チェック
                      final emailRegex = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$");
                      if (!emailRegex.hasMatch(emailTrimmed)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('メールアドレスの形式が正しくありません。')),
                        );
                        return;
                      }

                      try {
                        final userCredential = await _auth.signInWithEmailAndPassword(
                          email: emailTrimmed,
                          password: passwordTrimmed,
                        );
                        final user = userCredential.user;
                        if (user != null && !user.emailVerified) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('メールアドレスが確認されていません。確認してください。')),
                          );
                          await _auth.signOut();
                          return;
                        }

                        await requestTrackingPermission();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const MainPage()),
                              (route) => false,
                        );
                      } on FirebaseAuthException catch (e) {
                        String errorMessage;
                        switch (e.code) {
                          case 'user-disabled':
                            errorMessage = 'このユーザーアカウントは無効化されています。';
                            break;
                          case 'user-not-found':
                            errorMessage = 'ユーザーが見つかりません。メールアドレスを確認してください。';
                            break;
                          case 'wrong-password':
                            errorMessage = 'パスワードが間違っています。';
                            break;
                          default:
                            errorMessage = 'エラーが発生しました（${e.message}）';
                            break;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errorMessage)),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('予期しないエラーが発生しました: $e')),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ).copyWith(
                      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.pressed)) {
                          return AppColors.gray50;
                        }
                        return null;
                      }),
                    ),
                    child: const Text(
                      'ログインする',
                      style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                  ),
                  child: const Text(
                    '新規登録はこちら',
                    style: TextStyle(
                      color: AppColors.blue600,
                      decorationColor: AppColors.blue600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}