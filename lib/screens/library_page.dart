import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:repaso/screens/paywall_page.dart';
import 'package:repaso/screens/study_set_add_page.dart' as AddPage;
import 'package:repaso/utils/app_colors.dart';

import '../widgets/library_page/folder_tab_page.dart';
import '../widgets/library_page/anki_set_tab_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isPro = false;

  // FolderTabPage の State へアクセスするためのキー
  final GlobalKey<FolderTabPageState> _folderTabKey =
  GlobalKey<FolderTabPageState>();

  late final void Function(CustomerInfo) _customerInfoListener;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    // ── RevenueCat ─────────────────────────────
    Purchases.getCustomerInfo().then((info) {
      final active = info.entitlements.active['Pro']?.isActive ?? false;
      setState(() => _isPro = active);
    });

    _customerInfoListener = (CustomerInfo info) {
      final active = info.entitlements.active['Pro']?.isActive ?? false;
      if (_isPro != active) setState(() => _isPro = active);
    };
    Purchases.addCustomerInfoUpdateListener(_customerInfoListener);
    // ───────────────────────────────────────────
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_customerInfoListener);
    _tabController.dispose();
    super.dispose();
  }

  // 暗記セット追加画面へ
  Future<void> _navigateToAddStudySetPage(BuildContext context) async {
    final studySet = AddPage.StudySet(
      name: '',
      questionSetIds: [],
      numberOfQuestions: 10,
      selectedQuestionOrder: 'random',
      correctRateRange: const RangeValues(0, 100),
      isFlagged: false,
      memoryLevelStats: {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      memoryLevelRatios: {'again': 0, 'hard': 0, 'good': 0, 'easy': 0},
      totalAttemptCount: 0,
      studyStreakCount: 0,
      lastStudiedDate: '',
      selectedMemoryLevels: ['again', 'hard', 'good', 'easy'],
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPage.StudySetAddPage(studySet: studySet),
      ),
    );

    // 追加後はフォルダ側のリストも再取得
    if (result == true) _folderTabKey.currentState?.fetchFirebaseData();
  }

  // FAB 押下時のハンドラ
  Future<void> _onFabPressed(BuildContext context) async {
    if (_tabController.index == 0) {
      // フォルダタブ：フォルダ / 資格追加メニュー
      _folderTabKey.currentState?.showAddOptionsModal(context);
    } else {
      // 暗記セットタブ
      final user = FirebaseAuth.instance.currentUser!;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('studySets')
          .where('isDeleted', isEqualTo: false)
          .get();

      final hasAtLeastOne = snap.docs.length >= 1;

      if (!_isPro && hasAtLeastOne) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PaywallPage(
              subtitle:
              '暗記セットは無料プランでは1件まで作成可能です。追加するには Pro プランにアップグレードしてください。',
            ),
          ),
        );
      } else {
        await _navigateToAddStudySetPage(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('ライブラリ',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold))),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ライブラリ',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.notifications_none_outlined,
                  color: AppColors.gray600, size: 23),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.1),
                ),
              ),
              height: 32,
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 2.5,
                indicatorColor: Colors.blue[800],
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 16),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                tabs: const [
                  Tab(text: 'フォルダ'),
                  Tab(text: '暗記セット'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            FolderTabPage(key: _folderTabKey),       // ← フォルダタブ
            const AnkiSetTabPage(),                  // ← 暗記セットタブ
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
          child: FloatingActionButton(
            onPressed: () => _onFabPressed(context),
            backgroundColor: Colors.blue[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
