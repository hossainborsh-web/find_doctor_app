import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_style.dart';
import '../core/theme/fd_palette.dart';
import '../core/widgets/fd_widgets.dart';
import '../services/cloud/demo_seeder.dart';

void openDemoExamples(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const DemoExamplesScreen()));

/// General Managers load (once) a set of fictional accounts that show every
/// part of the app, and see how to sign in as each of them.
class DemoExamplesScreen extends StatefulWidget {
  const DemoExamplesScreen({super.key});

  @override
  State<DemoExamplesScreen> createState() => _DemoExamplesScreenState();
}

class _DemoExamplesScreenState extends State<DemoExamplesScreen> {
  DemoInfo? _info;
  bool _checking = true;
  bool _loading = false;
  String? _error;
  final List<String> _steps = [];

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final info = await DemoSeeder.instance.info();
    if (!mounted) return;
    setState(() {
      _info = info;
      _checking = false;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _steps.clear();
    });
    try {
      final info = await DemoSeeder.instance.load(onStep: (step) {
        if (mounted) setState(() => _steps.add(step));
      });
      if (!mounted) return;
      setState(() => _info = info);
    } on DemoException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: const FdAppBar(title: 'Demo examples', showBack: true),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (info != null && info.isDone)
                  ..._loaded(context, info)
                else
                  ..._notLoaded(context),
              ],
            ),
    );
  }

  List<Widget> _notLoaded(BuildContext context) {
    final muted = context.fdColor(AppColors.grey);
    return [
      FdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_outlined,
                    color: context.fdColor(AppColors.primaryBlue)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Examples for teachers',
                      style: AppTextStyles.subtitle1
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Creates ${DemoSeeder.people.length} fictional people, so every '
              'part of Find Doctor has something to show: users with visits '
              'and chats, doctors, Doctor Managers, and Students and New '
              'Doctors at each hiring step (waiting, join day, offer, '
              'declined, hired). Their emails end in @example.com, so they '
              'never reach a real person.',
              style: AppTextStyles.bodyText2.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            if (_loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              for (final step in _steps.reversed.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $step',
                      style: AppTextStyles.caption.copyWith(color: muted)),
                ),
            ] else
              FdButton(
                label: _error == null ? 'Load demo examples' : 'Try again',
                icon: Icons.download_rounded,
                onPressed: _load,
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: AppTextStyles.bodyText2
                      .copyWith(color: AppColors.errorRed)),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _loaded(BuildContext context, DemoInfo info) {
    final muted = context.fdColor(AppColors.grey);
    final groups = <(String, List<DemoPerson>)>[
      ('Users', _of(DemoKind.user)),
      ('Doctor Managers (HR of their hospital)', _of(DemoKind.doctorManager)),
      ('Doctors', _of(DemoKind.doctor)),
      ('Students (fresh graduates)', _of(DemoKind.student)),
      ('New Doctors (from other hospitals)', _of(DemoKind.newDoctor)),
    ];
    return [
      FdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.successGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Demo examples are ready',
                      style: AppTextStyles.subtitle1
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Sign out, then sign in with any email below. Every demo '
              'account uses the same password:',
              style: AppTextStyles.bodyText2.copyWith(color: muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SelectableText(info.password,
                      style: AppTextStyles.headline2.copyWith(
                          fontSize: 22, letterSpacing: 1.2)),
                ),
                IconButton(
                  tooltip: 'Copy password',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: info.password));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password copied')));
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Only General Managers can see this page. Your own account '
              '(General Manager) shows the whole picture: Hiring & staff, all '
              'hospitals, alerts and stock.',
              style: AppTextStyles.caption.copyWith(color: muted),
            ),
          ],
        ),
      ),
      for (final (title, people) in groups) ...[
        const SizedBox(height: 18),
        FdSectionHeader(title: title),
        FdCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < people.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _PersonTile(person: people[i]),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  static List<DemoPerson> _of(DemoKind kind) =>
      DemoSeeder.people.where((person) => person.kind == kind).toList();
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});
  final DemoPerson person;

  @override
  Widget build(BuildContext context) {
    final muted = context.fdColor(AppColors.grey);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.practises ? person.doctorName : person.name,
                    style: AppTextStyles.bodyText2
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                SelectableText(person.email,
                    style: AppTextStyles.bodyText2.copyWith(
                        color: context.fdColor(AppColors.primaryBlue))),
                if (person.hospital.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(person.hospital,
                      style: AppTextStyles.caption.copyWith(color: muted)),
                ],
                const SizedBox(height: 6),
                Text(person.shows,
                    style: AppTextStyles.caption.copyWith(color: muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy email',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: person.email));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${person.email} copied')));
            },
          ),
        ],
      ),
    );
  }
}
