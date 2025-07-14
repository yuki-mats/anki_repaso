// ignore_for_file: avoid_classes_with_only_static_members
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ─────────────────────────────────────────────
/// ExamCountdownCard  ─ 「試験日まで」カード
/// ─────────────────────────────────────────────
class ExamCountdownCard extends StatefulWidget {
  const ExamCountdownCard({super.key});

  @override
  State<ExamCountdownCard> createState() => _ExamCountdownCardState();
}

class _ExamCountdownCardState extends State<ExamCountdownCard> {
  /* ─────────────── Firestore 関連 ─────────────── */
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _userSub;

  /* ───────── 試験日カウントダウン用 ───────── */
  DateTime? _examDate;
  Timer?    _countdownTimer;
  Duration  _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots()
        .listen(_onUserDoc);
  }

  void _onUserDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final settings = (snap.data()?['settings'] ?? {}) as Map<String, dynamic>;
    final ts = settings['examDate'] as Timestamp?;
    if (ts != null) {
      final d = ts.toDate();
      setState(() => _examDate = d);
      _startCountdownTimer();
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    if (_examDate == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = _examDate!.difference(DateTime.now());
      setState(() => _timeLeft = diff.isNegative ? Duration.zero : diff);
      if (diff.isNegative) _countdownTimer?.cancel();
    });
  }

  String _formattedTimeLeft() {
    final h = _timeLeft.inHours.remainder(24).toString().padLeft(2, '0');
    final m = _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  int _remainingDays() {
    if (_examDate == null) return 0;
    final diff = _examDate!.difference(DateTime.now()).inDays;
    return diff >= 0 ? diff : 0;
  }

  /* ───────── 試験日入力モーダル ───────── */
  Future<void> _showExamDateInputModal() async {
    String year  = _examDate != null ? DateFormat('yyyy').format(_examDate!) : '';
    String month = _examDate != null ? DateFormat('M').format(_examDate!)   : '';
    String day   = _examDate != null ? DateFormat('d').format(_examDate!)   : '';

    bool _isExistingDate(String y, String m, String d) {
      if (y.length != 4 || m.isEmpty || d.isEmpty) return true;
      final yy = int.tryParse(y);
      final mm = int.tryParse(m);
      final dd = int.tryParse(d);
      if (yy == null || mm == null || dd == null) return false;
      try {
        final dt = DateTime(yy, mm, dd);
        return dt.year == yy && dt.month == mm && dt.day == dd;
      } catch (_) {
        return false;
      }
    }

    String? _validateAll() {
      if (year.isEmpty || month.isEmpty || day.isEmpty) {
        return '年・月・日すべて入力してください';
      }
      if (int.tryParse(year) == null) return '年は4桁の数字で入力してください';
      if (year.length != 4) return '年は4桁で入力してください';
      final m = int.tryParse(month);
      if (m == null) return '月は数字のみ入力してください';
      if (m < 1 || m > 12) return '月は1〜12の範囲で入力してください';
      final d = int.tryParse(day);
      if (d == null) return '日は数字のみ入力してください';
      if (d < 1 || d > 31) return '日は1〜31の範囲で入力してください';
      if (!_isExistingDate(year, month, day)) return '存在しない日付です';
      return null;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        /* FocusNode & Controllers */
        final yearFocusNode = FocusNode();
        final yearCtrl   = TextEditingController(text: year);
        final monthCtrl  = TextEditingController(text: month);
        final dayCtrl    = TextEditingController(text: day);
        String? errorMsg;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          yearFocusNode.requestFocus();
        });

        return StatefulBuilder(
          builder: (context, setStateSB) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('試験日を設定',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.black87)
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      /* 年 */
                      SizedBox(
                        width: 110,
                        child: TextField(
                          focusNode: yearFocusNode,
                          controller: yearCtrl,
                          cursorColor: Colors.blue[800],
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                            counterText: '',
                            hintText: '2025',                                     // ★追加
                            hintStyle: TextStyle(color: Colors.grey[400]),        // ★追加
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 4,
                          onChanged: (v) {
                            year = v;
                            setStateSB(() => errorMsg = _validateAll());
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('年', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 16),
                      /* 月 */
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: monthCtrl,
                          cursorColor: Colors.blue[800],
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                            counterText: '',
                            hintText: '02',                                      // ★追加
                            hintStyle: TextStyle(color: Colors.grey[400]),        // ★追加
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 2,
                          onChanged: (v) {
                            month = v;
                            setStateSB(() => errorMsg = _validateAll());
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('月', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 16),
                      /* 日 */
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: dayCtrl,
                          cursorColor: Colors.blue[800],
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                            counterText: '',
                            hintText: '28',                                      // ★追加
                            hintStyle: TextStyle(color: Colors.grey[400]),        // ★追加
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 2,
                          onChanged: (v) {
                            day = v;
                            setStateSB(() => errorMsg = _validateAll());
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('日', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 16,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: errorMsg == null
                          ? const SizedBox.shrink()
                          : Text(errorMsg!,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                      ),
                      onPressed: () async {
                        final msg = _validateAll();
                        if (msg != null) {
                          setStateSB(() => errorMsg = msg);
                          return;
                        }
                        final dt =
                        DateTime(int.parse(year), int.parse(month), int.parse(day));
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(_uid)
                            .set(
                          {
                            'settings': {'examDate': Timestamp.fromDate(dt)},
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                          SetOptions(merge: true),
                        );
                        _examDate = dt;
                        _startCountdownTimer();
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('保存',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: _showExamDateInputModal,
        child: Container(
          height: 92,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text('試験日まで',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.black87)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _examDate != null ? '${_remainingDays()}日' : '-',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _examDate != null ? _formattedTimeLeft() : '--:--:--',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userSub.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
