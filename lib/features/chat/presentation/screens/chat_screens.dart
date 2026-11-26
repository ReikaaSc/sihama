part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

class _ConversationTab extends StatefulWidget {
  const _ConversationTab({
    required this.onBack,
    required this.onOpenChat,
    required this.report,
    required this.repository,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenChat;
  final CropReport? report;
  final SihamaChatRepository repository;

  @override
  State<_ConversationTab> createState() => _ConversationTabState();
}

class _ConversationTabState extends State<_ConversationTab> {
  final _searchController = TextEditingController();
  late Future<List<ChatMessage>> _messagesFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _messagesFuture = _loadMessages();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshMessages(),
    );
  }

  Future<List<ChatMessage>> _loadMessages() {
    final report = widget.report;
    return report == null
        ? Future.value(const <ChatMessage>[])
        : widget.repository.getChatMessages(report.id);
  }

  void _refreshMessages() {
    if (!mounted) return;
    setState(() => _messagesFuture = _loadMessages());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final reportCaption = report == null
        ? ''
        : '${report.id} · ${_reportTitle(report)}';

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Percakapan',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Sesi chat dengan penyuluh',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ChatMessage>>(
            future: _messagesFuture,
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const <ChatMessage>[];
              final latestMessage = messages.isEmpty ? null : messages.last;
              final searchText = _searchController.text.trim().toLowerCase();
              final searchableText = [
                reportCaption,
                latestMessage?.senderName ?? '',
                latestMessage?.text ?? '',
              ].join(' ').toLowerCase();
              final isVisible =
                  searchText.isEmpty || searchableText.contains(searchText);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        _inputDecoration('Cari nama, laporan, atau pesan')
                            .copyWith(
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: _muted,
                              ),
                              isDense: true,
                            ),
                  ),
                  const SizedBox(height: 10),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFA1241A),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Percakapan gagal dimuat: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFA1241A),
                              fontSize: 12,
                            ),
                          ),
                          TextButton(
                            onPressed: _refreshMessages,
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    )
                  else if (report == null)
                    const _EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Belum ada percakapan',
                      message: 'Percakapan akan tersedia setelah Anda membuat laporan.',
                    )
                  else if (isVisible)
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: widget.onOpenChat,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFD8F0D5),
                                child: Text(
                                  _initials(
                                    latestMessage?.senderName ?? 'Percakapan',
                                  ),
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      latestMessage?.senderName ??
                                          'Percakapan laporan',
                                      style: const TextStyle(
                                        color: _ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      reportCaption,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      latestMessage?.text ?? 'Belum ada pesan. Ketuk untuk memulai percakapan.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _ink,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (latestMessage != null)
                                Text(
                                  '${latestMessage.sentAt.hour.toString().padLeft(2, '0')}.${latestMessage.sentAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatScreen extends StatefulWidget {
  const _ChatScreen({
    required this.repository,
    required this.dataRepository,
    required this.role,
    required this.reportId,
    required this.reportCaption,
    required this.reportStatus,
    required this.currentUserName,
  });

  final SihamaChatRepository repository;
  final SihamaRepository dataRepository;
  final SihamaRole role;
  final String reportId;
  final String reportCaption;
  final String reportStatus;
  final String currentUserName;

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final _controller = TextEditingController();
  late Future<List<ChatMessage>> _messagesFuture;
  late String _reportStatus = widget.reportStatus;
  Timer? _refreshTimer;
  bool _reportRefreshFailed = false;

  String get _myName => widget.currentUserName;
  String get _partnerName =>
      widget.role == SihamaRole.pelapor ? 'Penyuluh' : 'Pelapor';

  bool _isOwnMessage(ChatMessage message) =>
      message.senderRole.trim().toLowerCase() ==
          widget.role.name.toLowerCase() ||
      message.senderRole.trim().toLowerCase() ==
          widget.role.label.toLowerCase();

  @override
  void initState() {
    super.initState();
    _messagesFuture = widget.repository.getChatMessages(widget.reportId);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshMessages();
      unawaited(_refreshReportStatus());
    });
  }

  void _refreshMessages() {
    if (!mounted) return;
    setState(
      () =>
          _messagesFuture = widget.repository.getChatMessages(widget.reportId),
    );
  }

  Future<void> _refreshReportStatus() async {
    try {
      final reports = await widget.dataRepository.getReports();
      for (final report in reports) {
        if (report.id == widget.reportId &&
            report.status != _reportStatus &&
            mounted) {
          setState(() => _reportStatus = report.status);
          break;
        }
      }
      _reportRefreshFailed = false;
    } catch (error) {
      if (!mounted || _reportRefreshFailed) return;
      _reportRefreshFailed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status laporan gagal diperbarui: $error')),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    _controller.clear();
    try {
      await widget.repository.addChatMessage(
        ChatMessage(
          reportId: widget.reportId,
          senderRole: widget.role.label,
          senderName: _myName,
          text: value,
          sentAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      _refreshMessages();
    } catch (error) {
      if (!mounted) return;
      _controller.text = value;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pesan gagal disimpan: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFD8F0D5),
              child: Text(
                _initials(_partnerName),
                style: const TextStyle(color: _green, fontSize: 11),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _partnerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Percakapan laporan',
                  style: TextStyle(fontSize: 10, color: _muted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.eco_outlined, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.reportCaption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _reportStatus,
                        style: TextStyle(fontSize: 10, color: _green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ChatMessage>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <ChatMessage>[];
                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (messages.isNotEmpty)
                      const Center(
                        child: Chip(
                          label: Text(
                            'Riwayat percakapan',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ...messages.map((message) {
                      final mine = _isOwnMessage(message);
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: mine
                                ? const Color(0xFF25833E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Text(
                                  message.senderName,
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                message.text,
                                style: TextStyle(
                                  color: mine ? Colors.white : _ink,
                                  height: 1.4,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${message.sentAt.hour.toString().padLeft(2, '0')}.${message.sentAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: mine ? Colors.white70 : _muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (snapshot.connectionState == ConnectionState.done &&
                        messages.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(22),
                        child: Text(
                          'Belum ada pesan. Mulai percakapan dengan mengirim pesan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFE3EAE5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: _green),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE4EBE5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        const SizedBox(height: 9),
        child,
      ],
    ),
  );
}

class _SymptomChips extends StatelessWidget {
  const _SymptomChips({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final symptoms = description
        .split(RegExp(r'[,;\n.]'))
        .map((value) => value.trim())
        .where((value) => value.length > 2)
        .take(4)
        .toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: symptoms
          .map(
            (symptom) => Chip(
              label: Text(symptom, style: const TextStyle(fontSize: 10)),
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFFF0F5F1),
              side: BorderSide.none,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFE2F0FF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          color: Color(0xFF3976A8),
          size: 15,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF315E82),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
