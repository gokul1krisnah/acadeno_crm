import 'dart:async';
import 'package:gap/gap.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_extension.dart';
import '../../../../shared/snackbar_alerts/snack_alert.dart';

class _CampaignReason {
  final String label;
  final Color bg;
  final Color fg;

  const _CampaignReason(this.label, this.bg, this.fg);

  static const blue = _CampaignReason(
    'Branch match',
    Color(0xFFE8F1FD),
    Color(0xFF1D4ED8),
  );
  static const interest = _CampaignReason(
    'Interest match',
    Color(0xFFE8F1FD),
    Color(0xFF1D4ED8),
  );
  static const targetYr = _CampaignReason(
    'Target year',
    Color(0xFFE8F1FD),
    Color(0xFF1D4ED8),
  );
  static const recent = _CampaignReason(
    'Recent lead',
    Color(0xFFE8F1FD),
    Color(0xFF1D4ED8),
  );
  static const warm = _CampaignReason(
    'Warm lead',
    Color(0xFFE6F4EA),
    Color(0xFF15803D),
  );
}

class _CampaignLead {
  final String id;
  final int rank;
  final String name;
  final String collegeBranchYear;
  final int score;
  final Color scoreBarColor;
  final List<_CampaignReason> reasons;
  final String lastContact;
  String? assignedExec;

  _CampaignLead({
    this.id = '',
    required this.rank,
    required this.name,
    required this.collegeBranchYear,
    required this.score,
    required this.scoreBarColor,
    required this.reasons,
    required this.lastContact,
    this.assignedExec,
  });

  _CampaignLead copyWith({int? rank, String? assignedExec}) {
    return _CampaignLead(
      id: id,
      rank: rank ?? this.rank,
      name: name,
      collegeBranchYear: collegeBranchYear,
      score: score,
      scoreBarColor: scoreBarColor,
      reasons: reasons,
      lastContact: lastContact,
      assignedExec: assignedExec ?? this.assignedExec,
    );
  }
}

class _CampaignData {
  final String id;
  final String title;
  final String badge;
  final String topics;
  final String branches;
  final String years;
  final String matchingLeads;
  final String score70Plus;
  int assignedCount;

  _CampaignData({
    this.id = '',
    required this.title,
    required this.badge,
    required this.topics,
    required this.branches,
    required this.years,
    required this.matchingLeads,
    required this.score70Plus,
    required this.assignedCount,
  });

  _CampaignData copyWith({
    String? id,
    String? title,
    String? badge,
    String? topics,
    String? branches,
    String? years,
    String? matchingLeads,
    String? score70Plus,
    int? assignedCount,
  }) {
    return _CampaignData(
      id: id ?? this.id,
      title: title ?? this.title,
      badge: badge ?? this.badge,
      topics: topics ?? this.topics,
      branches: branches ?? this.branches,
      years: years ?? this.years,
      matchingLeads: matchingLeads ?? this.matchingLeads,
      score70Plus: score70Plus ?? this.score70Plus,
      assignedCount: assignedCount ?? this.assignedCount,
    );
  }
}

class CampaignsView extends StatefulWidget {
  const CampaignsView({super.key});

  @override
  State<CampaignsView> createState() => _CampaignsViewState();
}

class _CampaignsViewState extends State<CampaignsView> {
  final TextEditingController _splitCountController = TextEditingController(
    text: '80',
  );
  bool _showAllCampaigns = false;
  int _activeCampaignIndex = 0;

  final List<String> _allExecutives = [];
  final Set<String> _selectedExecutives = {};

  static final List<_CampaignData> _defaultCampaigns = [
    _CampaignData(
      id: 'cmp_default_1',
      title: 'AI & Machine Learning Workshop',
      badge: 'Starts 14 Nov',
      topics: 'ai, python, ml',
      branches: 'CSE, IT, ECE',
      years: '2nd, 3rd',
      matchingLeads: '0',
      score70Plus: '0',
      assignedCount: 0,
    ),
    _CampaignData(
      id: 'cmp_default_2',
      title: 'Full Stack Web Bootcamp',
      badge: 'Starts 22 Nov',
      topics: 'web, react, node',
      branches: 'CSE, IT, BCA',
      years: '3rd, 4th',
      matchingLeads: '0',
      score70Plus: '0',
      assignedCount: 0,
    ),
    _CampaignData(
      id: 'cmp_default_3',
      title: 'Embedded Systems & Robotics Lab',
      badge: 'Starts 02 Dec',
      topics: 'iot, robotics, embedded',
      branches: 'ECE, EEE, MECH',
      years: '2nd, 3rd, 4th',
      matchingLeads: '0',
      score70Plus: '0',
      assignedCount: 0,
    ),
  ];

  late List<_CampaignData> _campaigns = List.from(_defaultCampaigns);
  List<_CampaignLead> _rankedLeads = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _liveLeadDocs = [];
  StreamSubscription? _leadsSubscription;
  StreamSubscription? _campaignsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchLiveExecutives();
    _listenLiveCampaigns();
    _listenLiveLeadsAndRank();
  }

  @override
  void dispose() {
    _leadsSubscription?.cancel();
    _campaignsSubscription?.cancel();
    _splitCountController.dispose();
    super.dispose();
  }

  void _listenLiveCampaigns() {
    _campaignsSubscription?.cancel();
    _campaignsSubscription = FirebaseFirestore.instance
        .collection('campaigns')
        .snapshots()
        .listen((snap) {
          if (snap.docs.isEmpty) {
            _seedDefaultCampaigns();
          } else {
            final live = snap.docs.map((doc) {
              final d = doc.data();
              return _CampaignData(
                id: doc.id,
                title: (d['title'] ?? 'Campaign').toString(),
                badge: (d['badge'] ?? 'Upcoming').toString(),
                topics: (d['topics'] ?? '').toString(),
                branches: (d['branches'] ?? '').toString(),
                years: (d['years'] ?? '').toString(),
                matchingLeads: (d['matchingLeads'] ?? '0').toString(),
                score70Plus: (d['score70Plus'] ?? '0').toString(),
                assignedCount: (d['assignedCount'] as num?)?.toInt() ?? 0,
              );
            }).toList();
            if (mounted) {
              setState(() {
                _campaigns = live;
                if (_activeCampaignIndex >= _campaigns.length) {
                  _activeCampaignIndex = 0;
                }
              });
              if (_liveLeadDocs.isNotEmpty) {
                _recalculateAllCampaignsAndActiveRanking();
              }
            }
          }
        });
  }

  void _seedDefaultCampaigns() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final c in _defaultCampaigns) {
      final docRef = FirebaseFirestore.instance.collection('campaigns').doc();
      batch.set(docRef, {
        'title': c.title,
        'badge': c.badge,
        'topics': c.topics,
        'branches': c.branches,
        'years': c.years,
        'matchingLeads': '0',
        'score70Plus': '0',
        'assignedCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  void _listenLiveLeadsAndRank() {
    _leadsSubscription?.cancel();
    _leadsSubscription = FirebaseFirestore.instance
        .collection('leads')
        .snapshots()
        .listen((snap) {
          _liveLeadDocs = snap.docs;
          _recalculateAllCampaignsAndActiveRanking();
        });
  }

  void _recalculateAllCampaignsAndActiveRanking() {
    if (_campaigns.isEmpty) return;

    // 1. Recalculate actual matching leads, score 70+, and assigned count for every campaign
    final updatedCampaigns = <_CampaignData>[];
    for (var idx = 0; idx < _campaigns.length; idx++) {
      final camp = _campaigns[idx];
      final targetBranches = camp.branches.toUpperCase();
      final targetTopics = camp.topics.toLowerCase();

      int matching = 0;
      int score70 = 0;
      int assigned = 0;

      for (final doc in _liveLeadDocs) {
        final d = doc.data();
        final branch = (d['branch'] ?? '').toString().toUpperCase();
        final course = (d['course'] ?? d['source'] ?? '')
            .toString()
            .toLowerCase();
        final status = (d['status'] ?? 'New').toString();
        final assignedTo = (d['assignedToName'] ?? d['assignedTo'])
            ?.toString()
            .trim();

        final isAssigned =
            assignedTo != null &&
            assignedTo.isNotEmpty &&
            assignedTo != 'null' &&
            assignedTo != 'Unassigned';
        if (isAssigned) assigned++;

        int s = 40;
        if (branch.isNotEmpty && targetBranches.contains(branch)) s += 25;
        if (course.isNotEmpty &&
            (course.contains('ai') ||
                course.contains('python') ||
                course.contains('workshop') ||
                targetTopics.contains(course))) {
          s += 20;
        }
        if (status.toLowerCase().contains('interest')) s += 15;
        s = s.clamp(20, 98);

        matching++;
        if (s >= 70) score70++;
      }

      updatedCampaigns.add(
        camp.copyWith(
          matchingLeads: '$matching',
          score70Plus: '$score70',
          assignedCount: assigned,
        ),
      );
    }

    // 2. Score and rank leads for the active campaign
    final activeCamp = updatedCampaigns[_activeCampaignIndex];
    final activeBranches = activeCamp.branches.toUpperCase();
    final activeTopics = activeCamp.topics.toLowerCase();

    final scoredList = <_CampaignLead>[];
    for (var i = 0; i < _liveLeadDocs.length; i++) {
      final doc = _liveLeadDocs[i];
      final d = doc.data();
      final name = (d['name'] ?? 'Lead ${i + 1}').toString();
      final college = (d['college'] ?? d['collegeBranch'] ?? 'College')
          .toString();
      final branch = (d['branch'] ?? '').toString().toUpperCase();
      final year = (d['year'] ?? '').toString();
      final course = (d['course'] ?? d['source'] ?? '')
          .toString()
          .toLowerCase();
      final status = (d['status'] ?? 'New').toString();
      final assignedTo = (d['assignedToName'] ?? d['assignedTo'])
          ?.toString()
          .trim();

      int score = 40;
      final reasons = <_CampaignReason>[];

      if (branch.isNotEmpty && activeBranches.contains(branch)) {
        score += 25;
        reasons.add(_CampaignReason.blue);
      }
      if (course.isNotEmpty &&
          (course.contains('ai') ||
              course.contains('python') ||
              course.contains('workshop') ||
              activeTopics.contains(course))) {
        score += 20;
        reasons.add(_CampaignReason.interest);
      }
      if (status.toLowerCase().contains('interest')) {
        score += 15;
        reasons.add(_CampaignReason.warm);
      } else if (status.toLowerCase().contains('new') ||
          status.toLowerCase().contains('assigned')) {
        score += 10;
        reasons.add(_CampaignReason.recent);
      }
      if (year.contains('2') || year.contains('3')) {
        reasons.add(_CampaignReason.targetYr);
      }

      score = score.clamp(20, 98);
      final barColor = score >= 70
          ? const Color(0xFF15803D)
          : (score >= 50 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8));

      final collegeBranchYear = [
        college,
        if (branch.isNotEmpty) branch,
        if (year.isNotEmpty) year,
      ].join(' · ');

      scoredList.add(
        _CampaignLead(
          id: doc.id,
          rank: i + 1,
          name: name,
          collegeBranchYear: collegeBranchYear,
          score: score,
          scoreBarColor: barColor,
          reasons: reasons.isEmpty ? [_CampaignReason.recent] : reasons,
          lastContact: LeadDateHelper.formatLastContact(
            lastContactAt: d['lastContactAt'],
            lastCalledAt: d['lastCalledAt'],
            rawLastContact: d['lastContact'],
            updatedAt: d['updatedAt'],
            createdAt: d['createdAt'],
            status: (d['status'] ?? '').toString(),
            timeline: (d['timeline'] as List?)?.toList(),
          ),
          assignedExec:
              (assignedTo != null &&
                  assignedTo.isNotEmpty &&
                  assignedTo != 'null' &&
                  assignedTo != 'Unassigned')
              ? assignedTo
              : null,
        ),
      );
    }

    scoredList.sort((a, b) => b.score.compareTo(a.score));
    final ranked = <_CampaignLead>[];
    for (var i = 0; i < scoredList.length; i++) {
      ranked.add(scoredList[i].copyWith(rank: i + 1));
    }

    if (mounted) {
      setState(() {
        _campaigns = updatedCampaigns;
        _rankedLeads = ranked;
      });
    }

    // Persist real live counts to Firestore so stale dummy numbers are erased permanently
    if (activeCamp.id.isNotEmpty && !activeCamp.id.startsWith('cmp_default_')) {
      FirebaseFirestore.instance
          .collection('campaigns')
          .doc(activeCamp.id)
          .update({
            'matchingLeads': activeCamp.matchingLeads,
            'score70Plus': activeCamp.score70Plus,
            'assignedCount': activeCamp.assignedCount,
          })
          .catchError((_) {});
    }
  }

  void _fetchLiveExecutives() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      if (snap.docs.isNotEmpty) {
        final names = snap.docs
            .map((d) => (d.data()['name'] ?? '').toString().trim())
            .where((n) => n.isNotEmpty)
            .toList();
        if (names.isNotEmpty && mounted) {
          setState(() {
            _allExecutives.clear();
            _allExecutives.addAll(names);
            _selectedExecutives.clear();
            _selectedExecutives.addAll(names.take(4));
          });
        }
      }
    } catch (_) {}
  }

  int get _splitTotal => int.tryParse(_splitCountController.text.trim()) ?? 0;

  int get _perExecCount {
    if (_selectedExecutives.isEmpty || _splitTotal <= 0) return 0;
    return (_splitTotal / _selectedExecutives.length).ceil();
  }

  void _assignCampaignLeads() async {
    if (_selectedExecutives.isEmpty || _splitTotal <= 0) return;
    final execs = _selectedExecutives.toList();
    final toAssignCount = _splitTotal.clamp(1, _rankedLeads.length);
    final targetLeads = _rankedLeads.take(toAssignCount).toList();

    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dateLabel = 'Today';
    final batch = FirebaseFirestore.instance.batch();

    setState(() {
      if (_campaigns.isNotEmpty) {
        _campaigns[_activeCampaignIndex].assignedCount += toAssignCount;
      }
      for (var i = 0; i < targetLeads.length; i++) {
        targetLeads[i].assignedExec = execs[i % execs.length];
      }
    });

    try {
      for (var i = 0; i < targetLeads.length; i++) {
        final lead = targetLeads[i];
        final targetExecName = execs[i % execs.length];

        if (lead.id.isNotEmpty && !lead.id.startsWith('fblead_')) {
          final docRef = FirebaseFirestore.instance
              .collection('leads')
              .doc(lead.id);
          batch.update(docRef, {
            'assignedTo': targetExecName,
            'assignedToName': targetExecName,
            'assignedDateKey': dateKey,
            'assignedDateLabel': dateLabel,
            'status': 'Assigned',
            'isDone': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final assignId = '${lead.id}_$dateKey';
          final assignRef = FirebaseFirestore.instance
              .collection('assignments')
              .doc(assignId);
          batch.set(assignRef, {
            'id': assignId,
            'leadId': lead.id,
            'leadName': lead.name,
            'executiveName': targetExecName,
            'dateKey': dateKey,
            'dateLabel': dateLabel,
            'isDone': false,
            'status': 'assigned',
            'assignedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (_campaigns.isNotEmpty) {
        final camp = _campaigns[_activeCampaignIndex];
        if (camp.id.isNotEmpty && !camp.id.startsWith('cmp_default_')) {
          FirebaseFirestore.instance
              .collection('campaigns')
              .doc(camp.id)
              .update({
                'assignedCount': FieldValue.increment(toAssignCount),
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }
      }

      await batch.commit();

      await FirebaseFirestore.instance.collection('audit_log').add({
        'action':
            'Assigned $toAssignCount campaign leads across ${execs.join(", ")}',
        'category': 'campaign_assignment',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (mounted) {
      SnackBarAlert.showToast(
        context: context,
        message:
            'Split top $toAssignCount leads ($_perExecCount each) across ${execs.join(", ")} for tomorrow.',
      );
    }
  }

  void _showNewCampaignDialog() {
    final titleCtrl = TextEditingController();
    final badgeCtrl = TextEditingController(text: 'Starts 25 Nov');
    final topicsCtrl = TextEditingController(text: 'ai, python, data science');
    final branchesCtrl = TextEditingController(text: 'CSE, IT, ECE');
    final yearsCtrl = TextEditingController(text: '2nd, 3rd');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create Workshop / Course Campaign',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(ctx.devicePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Campaign / Workshop title *',
                    hintText: 'e.g. Cloud & DevOps Bootcamp',
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: badgeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Start date label',
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: topicsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target topics (comma separated)',
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: branchesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target branches',
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: yearsCtrl,
                  decoration: const InputDecoration(labelText: 'Target years'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF8144),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final newCamp = _CampaignData(
                title: titleCtrl.text.trim(),
                badge: badgeCtrl.text.trim().isEmpty
                    ? 'Upcoming'
                    : badgeCtrl.text.trim(),
                topics: topicsCtrl.text.trim(),
                branches: branchesCtrl.text.trim(),
                years: yearsCtrl.text.trim(),
                matchingLeads: '1,120',
                score70Plus: '215',
                assignedCount: 0,
              );

              await FirebaseFirestore.instance.collection('campaigns').add({
                'title': newCamp.title,
                'badge': newCamp.badge,
                'topics': newCamp.topics,
                'branches': newCamp.branches,
                'years': newCamp.years,
                'matchingLeads': newCamp.matchingLeads,
                'score70Plus': newCamp.score70Plus,
                'assignedCount': 0,
                'createdByUid': FirebaseAuth.instance.currentUser?.uid,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              if (mounted) {
                setState(() {
                  _campaigns.insert(0, newCamp);
                  _activeCampaignIndex = 0;
                  _showAllCampaigns = false;
                });
                _listenLiveLeadsAndRank();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create & Rank Leads'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _campaigns.isNotEmpty
        ? _campaigns[_activeCampaignIndex]
        : _defaultCampaigns.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            MediaQuery.of(context).size.width < 768 ||
            constraints.maxWidth < 800;

        if (_showAllCampaigns) {
          return _buildAllCampaignsList(isMobile);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar: < All campaigns
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _showAllCampaigns = true),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Text(
                            '< All campaigns',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showNewCampaignDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Campaign'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF8144),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _showAllCampaigns = true),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Text(
                            '< All campaigns',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showNewCampaignDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Campaign'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF8144),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
            const Gap(12),

            // Campaign Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8EAF0)),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCampaignInfoLeft(campaign),
                        const Gap(16),
                        _buildCampaignStatsRight(campaign, isMobile: true),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildCampaignInfoLeft(campaign)),
                        const Gap(24),
                        _buildCampaignStatsRight(campaign, isMobile: false),
                      ],
                    ),
            ),
            const Gap(14),

            // Split Top Leads Bar (Indigo border)
            // Split Top Leads Bar (Responsive Indigo border)
            LayoutBuilder(
              builder: (context, barC) {
                final isMobileBar = barC.maxWidth < 640;

                final splitInputRow = Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Split Top',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      width: 54,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _splitCountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const Text(
                      'Leads Evenly Across',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                );

                final execPills = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: _allExecutives.map((exec) {
                    final isSelected = _selectedExecutives.contains(exec);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected && _selectedExecutives.length > 1) {
                            _selectedExecutives.remove(exec);
                          } else {
                            _selectedExecutives.add(exec);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEEF0FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFFD0D5DD),
                            width: isSelected ? 1.3 : 1.0,
                          ),
                        ),
                        child: Text(
                          exec,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF475467),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );

                final assignBtn = SizedBox(
                  height: 38,
                  width: isMobileBar ? double.infinity : null,
                  child: ElevatedButton(
                    onPressed: _assignCampaignLeads,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF8144),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      'Assign For Tomorrow',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );

                if (isMobileBar) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFC7D2FE),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            splitInputRow,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF0FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$_perExecCount each',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4338CA),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(12),
                        execPills,
                        const Gap(12),
                        assignBtn,
                      ],
                    ),
                  );
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFC7D2FE),
                      width: 1.2,
                    ),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [splitInputRow, execPills],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_perExecCount each',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475467),
                            ),
                          ),
                          const Gap(14),
                          assignBtn,
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const Gap(14),

            // Ranked Leads Table / Mobile List
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8EAF0)),
              ),
              child: isMobile
                  ? _buildMobileRankedList()
                  : _buildDesktopRankedTable(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCampaignInfoLeft(_CampaignData campaign) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              campaign.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF0E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                campaign.badge,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9A3412),
                ),
              ),
            ),
          ],
        ),
        const Gap(10),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            _buildMetaInline('Topics: ', campaign.topics),
            _buildMetaInline('Branches: ', campaign.branches),
            _buildMetaInline('Years: ', campaign.years),
          ],
        ),
        const Gap(8),
        const Text(
          'SCORE = BRANCH MATCH 30 · INTEREST MATCH 30 · ATTENDED SIMILAR EVENT 20 · WARM LEAD 15 · TARGET YEAR 10 -\nRECENT LEAD 5 · CALLED IN LAST 7 DAYS -25 · NOT INTERESTED -30',
          style: TextStyle(
            fontSize: 10.5,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaInline(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF344054)),
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildCampaignStatsRight(
    _CampaignData campaign, {
    required bool isMobile,
  }) {
    final boxes = [
      _buildStatMiniBox(
        campaign.matchingLeads,
        'Matching leads',
        const Color(0xFF0F172A),
      ),
      _buildStatMiniBox(
        campaign.score70Plus,
        'Score 70+',
        const Color(0xFF15803D),
      ),
      _buildStatMiniBox(
        '${campaign.assignedCount}',
        'Assigned',
        const Color(0xFF4F46E5),
      ),
    ];

    if (isMobile) {
      return Row(
        children: [
          Expanded(child: boxes[0]),
          const Gap(8),
          Expanded(child: boxes[1]),
          const Gap(8),
          Expanded(child: boxes[2]),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 112, child: boxes[0]),
        const Gap(10),
        SizedBox(width: 104, child: boxes[1]),
        const Gap(10),
        SizedBox(width: 104, child: boxes[2]),
      ],
    );
  }

  Widget _buildStatMiniBox(String value, String label, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
          const Gap(4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopRankedTable() {
    const headerStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: Color(0xFF475467),
      letterSpacing: 0.5,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth =
            constraints.maxWidth < 1180 ? 1180.0 : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE8EAF0)),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 44, child: Text('#', style: headerStyle)),
                      Expanded(flex: 3, child: Text('NAME', style: headerStyle)),
                      Expanded(
                        flex: 4,
                        child: Text('COLLEGE & BRANCH', style: headerStyle),
                      ),
                      Expanded(flex: 2, child: Text('SCORE', style: headerStyle)),
                      Expanded(
                        flex: 5,
                        child: Text(
                          'REASONS FOR HIGH SCORE',
                          style: headerStyle,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('LAST CONTACT', style: headerStyle),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: Text('ASSIGNED', style: headerStyle),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_rankedLeads.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No leads found in database. Import or add leads to see ranked campaign candidates.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  )
                else
                  for (var index = 0; index < _rankedLeads.length; index++) ...[
                    if (index > 0)
                      const Divider(height: 1, color: Color(0xFFE8EAF0)),
                    Builder(
                      builder: (context) {
                        final lead = _rankedLeads[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '${lead.rank}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  lead.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  lead.collegeBranchYear,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475467),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: lead.score / 100,
                                          minHeight: 6,
                                          color: lead.scoreBarColor,
                                          backgroundColor: const Color(
                                            0xFFE5E7EB,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Gap(8),
                                    Text(
                                      '${lead.score}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: lead.scoreBarColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 5,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: lead.reasons.map((r) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        r.label.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4F46E5),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  lead.lastContact,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: lead.assignedExec != null
                                    ? Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF0FF),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            lead.assignedExec!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF4338CA),
                                            ),
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Text(
                                          '—',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileRankedList() {
    if (_rankedLeads.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No leads found in database. Import or add leads to see ranked campaign candidates.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF667085),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _rankedLeads.length,
      separatorBuilder: (_, _) => const Gap(12),
      itemBuilder: (context, index) {
        final lead = _rankedLeads[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EAF0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF0FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '#${lead.rank}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            lead.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (lead.assignedExec != null) ...[
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF0FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lead.assignedExec!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Gap(6),
              Text(
                lead.collegeBranchYear,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475467),
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: lead.score / 100,
                        minHeight: 6,
                        color: lead.scoreBarColor,
                        backgroundColor: const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  const Gap(10),
                  Text(
                    'Score ${lead.score}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: lead.scoreBarColor,
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: lead.reasons.map((r) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: r.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: r.fg,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllCampaignsList(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campaigns & Workshop Targeting',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Gap(4),
                  const Text(
                    'Rank and assign historical leads automatically for upcoming events',
                    style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
                  ),
                  const Gap(12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showNewCampaignDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New campaign'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF8144),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campaigns & Workshop Targeting',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Gap(4),
                      Text(
                        'Rank and assign historical leads automatically for upcoming events',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showNewCampaignDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New campaign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF8144),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
        const Gap(18),
        ...List.generate(_campaigns.length, (index) {
          final c = _campaigns[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EAF0)),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            c.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF0E6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              c.badge,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9A3412),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(6),
                      Text(
                        'Topics: ${c.topics} · Branches: ${c.branches}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475467),
                        ),
                      ),
                      const Gap(12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _activeCampaignIndex = index;
                              _showAllCampaigns = false;
                            });
                            _recalculateAllCampaignsAndActiveRanking();
                          },
                          child: const Text('View ranked leads'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  c.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF0E6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    c.badge,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9A3412),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(6),
                            Text(
                              'Topics: ${c.topics} · Branches: ${c.branches}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475467),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _activeCampaignIndex = index;
                            _showAllCampaigns = false;
                          });
                          _recalculateAllCampaignsAndActiveRanking();
                        },
                        child: const Text('View ranked leads'),
                      ),
                    ],
                  ),
          );
        }),
      ],
    );
  }
}
