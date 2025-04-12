import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:repaso/widgets/common_widgets/common_text_field.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'main.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';
import 'utils/app_colors.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  SignUpPageState createState() => SignUpPageState();
}

class SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  String? passwordError;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: []);

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithPopup(googleProvider);

        final user = userCredential.user;
        if (user != null) {
          final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          await userRef.set({
            'name': '未設定',
            'joinedGroups': [],
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainPage()),
          );
        }
        return user;
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user != null) {
          final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          await userRef.set({
            'name': '未設定',
            'joinedGroups': [],
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainPage()),
          );
        }
        return user;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Googleサインインに失敗しました: $e')),
      );
      return null;
    }
  }

  Future<User?> signInWithApple() async {
    try {
      if (kIsWeb) {
        final OAuthProvider appleProvider = OAuthProvider('apple.com');
        appleProvider.addScope('email');
        appleProvider.addScope('name');
        final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithPopup(appleProvider);

        final user = userCredential.user;
        if (user != null) {
          final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          await userRef.set({
            'name': '未設定',
            'joinedGroups': [],
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainPage()),
          );
        }
        return user;
      } else {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        );
        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: credential.identityToken,
          accessToken: credential.authorizationCode,
        );

        final userCredential = await _auth.signInWithCredential(oauthCredential);
        final user = userCredential.user;
        if (user != null) {
          final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          await userRef.set({
            'name': '未設定',
            'joinedGroups': [],
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainPage()),
          );
        }
        return user;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appleサインインに失敗しました: $e')),
      );
      return null;
    }
  }

  void _validatePassword(String password) {
    setState(() {
      if (password.length < 8 || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(password)) {
        passwordError = 'パスワードは8文字以上の英数字で入力してください。';
      } else {
        passwordError = null;
      }
    });
  }

  bool get isSignUpEnabled {
    return _passwordController.text == _confirmPasswordController.text &&
        passwordError == null &&
        _passwordController.text.isNotEmpty;
  }

  Future<void> _signUpUser() async {
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final User? user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': '未設定',
          'joinedGroups': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        await user.sendEmailVerification();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('確認メールを送信しました。メールを確認してください。')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'weak-password') {
        errorMessage = 'パスワードが短すぎます。強力なパスワードを選んでください。';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'このメールアドレスは既に登録されています。';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'メールアドレスの形式が正しくありません。';
      } else {
        errorMessage = 'エラーが発生しました。もう一度お試しください。';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('予期しないエラーが発生しました: $e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('新規登録', style: TextStyle(color: Colors.black, fontSize: 18)),
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
                  onPressed: signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center, // ← 上下中央揃え！
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.g_mobiledata_sharp, color: Colors.white, size: 36),
                      Text('Googleで登録', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.apple, color: Colors.white, size: 24),
                    label: const Text(
                      'Appleで登録',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: signInWithApple,
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('または、メールアドレスで登録'),
                    ),
                    Expanded(child: Divider(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 24),
                CommonTextField(
                  controller: _emailController,
                  labelText: 'メールアドレス',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                CommonTextField(
                  controller: _passwordController,
                  labelText: 'パスワード(8文字以上)',
                  obscureText: !isPasswordVisible,
                  onChanged: _validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                  ),
                  errorText: passwordError,
                ),
                const SizedBox(height: 16),
                CommonTextField(
                  controller: _confirmPasswordController,
                  labelText: 'パスワード確認',
                  obscureText: !isConfirmPasswordVisible,
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    icon: Icon(isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => isConfirmPasswordVisible = !isConfirmPasswordVisible),
                  ),
                  errorText: _passwordController.text != _confirmPasswordController.text &&
                      _confirmPasswordController.text.isNotEmpty
                      ? 'パスワードが一致しません。'
                      : null,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black, fontSize: 12),
                      children: [
                        const TextSpan(text: '登録を続行すると、'),
                        TextSpan(
                          text: '利用規約',
                          style: const TextStyle(
                            color: AppColors.blue600,
                            decoration: TextDecoration.none,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                            ),
                        ),
                        const TextSpan(text: 'および'),
                        TextSpan(
                          text: 'プライバシーポリシー',
                          style: const TextStyle(
                            color: AppColors.blue600,
                            decoration: TextDecoration.none,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                            ),
                        ),
                        const TextSpan(text: 'に同意したものとみなされます。'),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSignUpEnabled ? _signUpUser : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSignUpEnabled ? AppColors.blue600 : Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('登録する', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  ),
                  child: const Text(
                    'ログインする',
                    style: TextStyle(
                      color: AppColors.blue600,
                      decorationColor: AppColors.blue600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
