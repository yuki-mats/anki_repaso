import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:repaso/folder_list_page.dart';
import 'package:repaso/privacy_policy_page.dart';
import 'package:repaso/terms_of_service_page.dart';
import 'app_colors.dart';
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Firestoreにユーザー情報を保存
        final DocumentReference userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

        await userRef.set({
          'name': user.email ?? 'Google User', // メールアドレスが取得できない場合のフォールバック
          'email': user.email,
          'createdQuestions': [],
          'joinedGroups': [],
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // 既存データがある場合はマージ

        setState(() {
        });

        // カテゴリーリストページに遷移
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const FolderListPage(title: "ホーム"),
          ),
        );
      }
      return user;
    } catch (e) {
      print("Error during Google Sign In: $e");
      return null;
    }
  }


  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    setState(() {
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Firestoreに新規ユーザーを追加
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _emailController.text, // ユーザー名としてメールアドレスを使用
          'email': _emailController.text,
          'createdQuestions': [],
          'joinedGroups': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 確認メールを送信
        await user.sendEmailVerification();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('確認メールを送信しました。メールを確認してください。')),
        );

        // ログインページに遷移
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  '新規登録',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'メールアドレス',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: !isPasswordVisible,
                  keyboardType: TextInputType.visiblePassword,
                  onChanged: (value) {
                    _validatePassword(value);
                  },
                  decoration: InputDecoration(
                    labelText: 'パスワード(8文字以上)',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                    errorText: passwordError,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !isConfirmPasswordVisible,
                  keyboardType: TextInputType.visiblePassword,
                  onChanged: (_) {
                    setState(() {}); // 確認パスワードの再チェック
                  },
                  decoration: InputDecoration(
                    labelText: 'パスワード確認',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isConfirmPasswordVisible = !isConfirmPasswordVisible;
                        });
                      },
                    ),
                    errorText: _passwordController.text != _confirmPasswordController.text &&
                        _confirmPasswordController.text.isNotEmpty
                        ? 'パスワードが一致しません。'
                        : null,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: RichText(
                        text: TextSpan(
                          text: '「',
                          style: const TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: '利用規約',
                              style: const TextStyle(
                                color: AppColors.blue600,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TermsOfServicePage(),
                                    ),
                                  );
                                },
                            ),
                            const TextSpan(
                              text: '」および「',
                              style: TextStyle(color: Colors.black),
                            ),
                            TextSpan(
                              text: 'プライバシーポリシー',
                              style: const TextStyle(
                                color: AppColors.blue600,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const PrivacyPolicyPage(),
                                    ),
                                  );
                                },
                            ),
                            const TextSpan(
                              text: '」に同意して',
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSignUpEnabled ? _signUpUser : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSignUpEnabled ? AppColors.blue600 : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '登録する',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'ログインする',
                    style: TextStyle(
                      color: AppColors.blue600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.blue600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.grey)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('または'),
                    ),
                    Expanded(child: Divider(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.g_mobiledata_sharp, color: Colors.black, size: 44),
                    label: const Text('Googleで登録', style: TextStyle(color: Colors.black, fontSize: 18)),
                    onPressed: () {
                      signInWithGoogle();
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.apple, color: Colors.black, size: 32),
                    label: const Text('Appleで登録', style: TextStyle(color: Colors.black, fontSize: 18)),
                    onPressed: () {
                      // Appleで登録処理
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
