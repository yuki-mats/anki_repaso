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
    /* ───── settings.examDate を監視 ───── */
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .snapshots()
        .listen(_onUserDoc);
  }

  /* ───────── settings.examDate が更新された ───────── */
  void _onUserDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final settings = (snap.data()?['settings'] ?? {}) as Map<String, dynamic>;
    final ts       = settings['examDate'] as Timestamp?;
    if (ts != null) {
      final d = ts.toDate();
      setState(() => _examDate = d);
      _startCountdownTimer();
    }
  }

  /* ────────── カウントダウン ────────── */
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
    final formKey = GlobalKey<FormState>();
    String year  = _examDate != null ? DateFormat('yyyy').format(_examDate!) : '';
    String month = _examDate != null ? DateFormat('M').format(_examDate!)   : '';
    String day   = _examDate != null ? DateFormat('d').format(_examDate!)   : '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final yearFocusNode = FocusNode();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(ctx).requestFocus(yearFocusNode);
        });

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('試験日を入力',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.black87)),
              const SizedBox(height: 20),
              Form(
                key: formKey,
                child: Row(
                  children: [
                    /* 年 */
                    Expanded(
                      child: TextFormField(
                        focusNode: yearFocusNode,
                        autofocus: true,
                        initialValue: year,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '年',
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 4,
                        onChanged: (v) {
                          year = v;
                          if (v.length == 4) FocusScope.of(ctx).nextFocus();
                        },
                        validator: (v) {
                          if (v == null || v.isEmpty) return '年を入力';
                          if (int.tryParse(v) == null) return '数字のみ';
                          return null;
                        },
                        onSaved: (v) => year = v!,
                      ),
                    ),
                    const SizedBox(width: 16),
                    /* 月 */
                    Expanded(
                      child: TextFormField(
                        initialValue: month,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '月',
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 2,
                        onChanged: (v) {
                          month = v;
                          if (v.length == 2) FocusScope.of(ctx).nextFocus();
                        },
                        validator: (v) {
                          final m = int.tryParse(v ?? '');
                          if (m == null) return '数字のみ';
                          if (m < 1 || m > 12) return '1〜12の範囲';
                          return null;
                        },
                        onSaved: (v) => month = v!,
                      ),
                    ),
                    const SizedBox(width: 16),
                    /* 日 */
                    Expanded(
                      child: TextFormField(
                        initialValue: day,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '日',
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 2,
                        onChanged: (v) => day = v,
                        validator: (v) {
                          final d = int.tryParse(v ?? '');
                          if (d == null) return '数字のみ';
                          if (d < 1 || d > 31) return '1〜31の範囲';
                          return null;
                        },
                        onSaved: (v) => day = v!,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    formKey.currentState!.save();
                    _examDate = DateTime(
                        int.parse(year), int.parse(month), int.parse(day));
                    /* Firestore へ保存 (保持したい場合) */
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_uid)
                        .set(
                      {
                        'settings': {
                          'examDate': Timestamp.fromDate(_examDate!)
                        },
                        'updatedAt': FieldValue.serverTimestamp(),
                      },
                      SetOptions(merge: true),
                    );
                    _startCountdownTimer();
                    if (mounted) Navigator.pop(ctx);
                  },
                  child: const Text('更新'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /* ───────── build ───────── */
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
                  Icon(Icons.calendar_today, color: Colors.black54, size: 16),
                  const SizedBox(width: 4),
                  Text('試験日まで',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.black54)),
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

  /* ───────── クリーンアップ ───────── */
  @override
  void dispose() {
    _userSub.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
