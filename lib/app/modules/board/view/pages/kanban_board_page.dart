import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/api_config.dart';
import '../../../../gitlab_status.dart';
import '../../../../models/activity_notification.dart';
import '../../../../models/project_models.dart';
import '../../../../services/panel_repository.dart';
import '../widgets/activity_feed_bar.dart';
import '../widgets/kanban_column.dart';

class KanbanBoardPage extends StatefulWidget {
  const KanbanBoardPage({super.key});

  @override
  State<KanbanBoardPage> createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage> {
  final PanelRepository _repo = PanelRepository();
  final ScrollController _boardHScroll = ScrollController();
  Timer? _fallbackTimer;
  Timer? _debounceRefresh;
  bool _loading = true;
  bool _realtimeLive = false;

  /// `null` = todos os projetos; senão só panel, log ou farm.
  String? _selectedProject;

  List<ProjectPanel> get projects => _repo.projects;
  List<ActivityNotification> get activities => _repo.activities;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_loading) _refreshBoard(silent: true);
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _debounceRefresh?.cancel();
    _boardHScroll.dispose();
    _repo.stopRealtime();
    super.dispose();
  }

  void _scheduleBoardRefresh() {
    _debounceRefresh?.cancel();
    _debounceRefresh = Timer(const Duration(milliseconds: 120), () {
      debugPrint('[panel] debounce → _refreshBoard');
      if (mounted) _refreshBoard(silent: true);
    });
  }

  Future<void> _refreshBoard({bool silent = false}) async {
    debugPrint(
      '[panel] _refreshBoard início (silent=$silent, api=${_repo.apiConnected})',
    );
    final revBefore = _repo.boardRevision;
    await _repo.refreshBoard();
    if (mounted) {
      final columns = buildCentralizedBoard(
        projects,
        filterProject: _selectedProject,
      );
      final mrCol = columns.where((c) => c.id == 'merge_request').firstOrNull;
      debugPrint(
        '[panel] UI coluna Merge: ${mrCol?.cards.length ?? 0} cartão(s) '
        'rev=${_repo.boardRevision} (antes=$revBefore)',
      );
      if (_repo.boardRevision != revBefore &&
          (mrCol?.cards.isNotEmpty ?? false)) {
        _scrollToMergeColumn();
      }
      debugPrint('[panel] _refreshBoard → setState');
      setState(() {});
      if (!silent) {
        _showConnectionSnackBar(onlyOnError: true);
      } else if (_repo.apiConnected && !_realtimeLive) {
        _startRealtime();
      }
    }
  }

  String _formatClock(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  DateTime? get _lastGitLabWebhookAt {
    final raw = _repo.gitlabSetup?.webhook?.lastAt;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String get _syncStatusLine {
    final panel = _formatClock(_repo.lastBoardSyncAt);
    final gitlab = _formatClock(_lastGitLabWebhookAt);
    if (_repo.apiConnected) {
      final mode = _realtimeLive ? 'tempo real' : 'poll 2s';
      return 'Painel $panel · GitLab $gitlab · $mode';
    }
    return 'Sem sync · painel $panel';
  }

  void _scrollToMergeColumn() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_boardHScroll.hasClients) return;
      const colWidth = 252.0; // 240 + padding
      final target = colWidth * 2; // pipeline, job, merge
      debugPrint(
        '[panel] scroll → coluna Merge requests (~${target.toInt()}px)',
      );
      _boardHScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _startRealtime() {
    _repo.stopRealtime();
    _repo.startRealtime(
      onUpdate: () {
        if (mounted) _scheduleBoardRefresh();
      },
      onStatus: (connected) {
        if (mounted) setState(() => _realtimeLive = connected);
      },
    );
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await _repo.load();
    if (mounted) {
      setState(() => _loading = false);
      _showConnectionSnackBar();
      if (_repo.apiConnected) _startRealtime();
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    await _repo.load();
    if (mounted) {
      setState(() {});
      if (!silent) {
        _showConnectionSnackBar(onlyOnError: true);
      } else if (_repo.apiConnected && !_realtimeLive) {
        _startRealtime();
      }
    }
  }

  void _showConnectionSnackBar({bool onlyOnError = false}) {
    if (!mounted) return;
    if (_repo.apiConnected) {
      if (!onlyOnError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conectado à API — feed do GitLab ativo'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    final err = _repo.connectionError ?? 'desconhecido';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'API offline ($panelApiBaseUrl). Mostrando dados locais.\n$err',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  bool get _webhookNeedsSecret =>
      _repo.gitlabSetup?.webhook?.needsSecretFix == true;

  Future<void> _showSyncSecretDialog() async {
    final secretCtrl = TextEditingController();
    final wh = _repo.gitlabSetup?.webhook;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Sincronizar secret do webhook',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wh?.lastMessage ??
                  'O GitLab está enviando eventos, mas o Secret token não confere.',
              style: const TextStyle(color: Color(0xFFE0A060), fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'No GitLab → Settings → Webhooks, copie o Secret token e cole aqui:',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: secretCtrl,
              autofocus: true,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Secret token do GitLab',
                hintStyle: TextStyle(color: Color(0xFF555555)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      secretCtrl.dispose();
      return;
    }
    final secret = secretCtrl.text.trim();
    secretCtrl.dispose();
    if (secret.isEmpty) return;

    try {
      await _repo.syncWebhookSecret(secret);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Secret salvo. No GitLab, teste o webhook de novo (deve dar 201).',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar secret: $e')));
    }
  }

  void _showGitlabSetup() {
    final setup = _repo.gitlabSetup;
    final webhookUrl =
        setup?.webhookUrl(panelApiBaseUrl) ??
        '$panelApiBaseUrl/api/webhooks/gitlab';
    final wh = setup?.webhook;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Conectar GitLab',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _repo.apiConnected
                    ? 'API conectada · eventos do GitLab chegam pelo webhook.'
                    : 'API offline — suba o Docker e configure PANEL_API_URL.',
                style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'URL do webhook (cole no GitLab):',
                style: TextStyle(color: Color(0xFF888888), fontSize: 11),
              ),
              const SizedBox(height: 4),
              SelectableText(
                webhookUrl,
                style: const TextStyle(color: Color(0xFF6BC04A), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Text(
                'Eventos: ${setup?.events.join(", ") ?? "pipeline, job, merge_request, note, issue"}',
                style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
              ),
              if (setup?.flowHint != null && setup!.flowHint!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    setup.flowHint!,
                    style: const TextStyle(
                      color: Color(0xFF9FD68A),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Quadro único: panel, projeto fake e repositorio teste na mesma tela.\n'
                  'Pipeline: uma linha por branch · atualização em tempo real (SSE).\n'
                  'Atividade embaixo: última atualização de cada projeto.',
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
              if (wh != null && wh.needsSecretFix)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '⚠ Webhook bloqueado (401): secret diferente do GitLab.\n'
                    'Toque em "Sincronizar secret" abaixo.',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                )
              else if (setup?.secretConfigured == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    wh?.lastOk == true
                        ? 'Último webhook: OK (${wh?.lastKind ?? ""})'
                        : 'Secret configurado (${wh?.secretLength ?? 0} caracteres)',
                    style: const TextStyle(
                      color: Color(0xFF6BC04A),
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'API: $panelApiBaseUrl',
                style: const TextStyle(color: Color(0xFF555555), fontSize: 10),
              ),
            ],
          ),
        ),
        actions: [
          if (wh?.needsSecretFix == true)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showSyncSecretDialog();
              },
              child: const Text('Sincronizar secret'),
            ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: webhookUrl));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('URL copiada')));
            },
            child: const Text('Copiar URL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMonitorDialog() async {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final setup = _repo.gitlabSetup;
    final webhookUrl =
        setup?.webhookUrl(panelApiBaseUrl) ??
        '$panelApiBaseUrl/api/webhooks/gitlab';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Monitorar projeto GitLab',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cole a URL do repositório no GitLab:',
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'https://gitlab.com/grupo/projeto',
                  hintStyle: TextStyle(color: Color(0xFF555555)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nome no painel (opcional):',
                style: TextStyle(color: Color(0xFF888888), fontSize: 11),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'ex.: panel',
                  hintStyle: TextStyle(color: Color(0xFF555555)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Depois, no GitLab → Settings → Webhooks, use:\n$webhookUrl',
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      urlCtrl.dispose();
      nameCtrl.dispose();
      return;
    }
    final url = urlCtrl.text.trim();
    final shortName = nameCtrl.text.trim().isEmpty
        ? null
        : nameCtrl.text.trim();
    urlCtrl.dispose();
    nameCtrl.dispose();

    if (url.isEmpty) return;

    try {
      final panel = await _repo.addMonitor(gitlabUrl: url, name: shortName);
      await _refresh();
      if (!mounted) return;
      _selectProject(panel.name);
      final hooksUrl = panel.gitlabPath != null
          ? 'https://gitlab.com/${panel.gitlabPath}/-/hooks'
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hooksUrl != null
                ? '“${panel.name}” adicionado. Webhook em:\n$hooksUrl'
                : '“${panel.name}” adicionado. Configure o webhook no GitLab.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível adicionar: $e')));
    }
  }

  Future<String?> _pickProject({required String title}) async {
    if (projects.isEmpty) return null;
    if (projects.length == 1) return projects.first.name;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in projects)
              ListTile(
                title: Text(
                  p.name,
                  style: const TextStyle(color: Color(0xFFE0E0E0)),
                ),
                onTap: () => Navigator.pop(ctx, p.name),
              ),
          ],
        ),
      ),
    );
  }

  GitLabCardStatus _statusForColumn(String colId) {
    if (colId.endsWith('-issue')) {
      return GitLabCardStatus.issue(GitLabIssueState.opened);
    }
    if (colId.endsWith('-merge_request')) {
      return GitLabCardStatus.mergeRequest(GitLabMrState.opened);
    }
    if (colId.endsWith('-job')) {
      return GitLabCardStatus.job(GitLabCiStatus.pending);
    }
    return GitLabCardStatus.pipeline(GitLabCiStatus.pending);
  }

  void _selectProject(String? name) {
    setState(() => _selectedProject = name);
  }

  Future<void> _addCard(String kindId) async {
    final project =
        _selectedProject ??
        await _pickProject(title: 'Adicionar em qual projeto?');
    if (project == null) return;
    try {
      await _repo.upsertBoardCard(
        projectName: project,
        issue: '#—',
        message: 'Novo item',
        status: _statusForColumn('$project-$kindId'),
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao adicionar: $e')));
      }
    }
  }

  Future<void> _deleteCard(CardModel card) async {
    final project = card.projectName;
    final column = card.columnId;
    if (project == null || column == null) return;
    try {
      await _repo.deleteBoardCard(
        projectName: project,
        columnId: column,
        cardId: card.id,
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao remover: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = buildCentralizedBoard(
      projects,
      filterProject: _selectedProject,
    );
    final chipNames = projectNamesOrdered(projects);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        shape: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ponto polly - LTDA.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF8FAFC),
                  letterSpacing: 0.02,
                ),
              ),
              Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _selectProject(null),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedProject == null
                          ? const Color(0xFF22C55E).withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedProject == null
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: _selectedProject == null
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      'Todos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _selectedProject == null
                            ? Colors.white
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ),
              ),
              ...chipNames.map(
                (name) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectProject(name),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedProject == name
                              ? const Color(0xFF22C55E).withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _selectedProject == name
                                ? const Color(0xFF4ADE80)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: _selectedProject == name
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF22C55E,
                                    ).withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _selectedProject == name
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: 'Adicionar projeto GitLab',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _repo.apiConnected ? _showAddMonitorDialog : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.add_link,
                              size: 18,
                              color: const Color(0xFFE2E8F0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: _repo.apiConnected
                      ? 'Atualizado ${_formatClock(_repo.lastBoardSyncAt)} · toque para refresh'
                      : 'API offline',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _refresh,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              _repo.apiConnected
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              size: 18,
                              color: _repo.apiConnected
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFF94A3B8),
                            ),
                            if (_repo.apiConnected && _realtimeLive)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22D3EE),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF0F172A),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: 'Conectar GitLab',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showGitlabSetup,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.hub_outlined,
                              size: 18,
                              color: const Color(0xFFE2E8F0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _BoardBannerBackground(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: MediaQuery.paddingOf(context).top + kToolbarHeight,
                ),
                if (_loading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: Color(0xFF4A7C2F),
                    backgroundColor: Color(0xFF222222),
                  ),
                if (!_loading && !_repo.apiConnected)
                  Material(
                    color: const Color(0xFF3D2A00).withValues(alpha: 0.92),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sem API em $panelApiBaseUrl — eventos GitLab não aparecem. Toque na nuvem para atualizar.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFE0C080),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_loading && _repo.apiConnected && _webhookNeedsSecret)
                  Material(
                    color: const Color(0xFF3D1515).withValues(alpha: 0.92),
                    child: InkWell(
                      onTap: _showSyncSecretDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_reset,
                              color: Color(0xFFEF4444),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'GitLab enviou push, mas o Secret token está errado (401). '
                                'Toque aqui para colar o secret do GitLab.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFF0A0A0),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFEF4444),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (!_loading && _repo.apiConnected)
                  Material(
                    color: const Color(0xFF1A2E14).withValues(alpha: 0.92),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF6BC04A),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _syncStatusLine,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9FD68A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 160),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        controller: _boardHScroll,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: columns.asMap().entries.map((entry) {
                            final col = entry.value;
                            final colSig = col.cards
                                .map(
                                  (c) =>
                                      '${c.id}:${c.status.apiValue}:${c.updatedAt?.millisecondsSinceEpoch ?? 0}',
                                )
                                .join('|');
                            return Padding(
                              padding: EdgeInsets.only(
                                right: entry.key == columns.length - 1 ? 0 : 12,
                              ),
                              child: KanbanColumn(
                                key: ValueKey(
                                  '${col.id}|$colSig|${_repo.boardRevision}',
                                ),
                                column: col,
                                onAddCard: () => _addCard(col.id),
                                onDeleteCard: _deleteCard,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ActivityFeedBar(
                projectNames: chipNames,
                activities: activities,
                selectedProject: _selectedProject,
                telegramEnabled: _repo.telegramEnabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardBannerBackground extends StatelessWidget {
  final Widget child;

  const _BoardBannerBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/banner3.png',
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
        child,
      ],
    );
  }
}
