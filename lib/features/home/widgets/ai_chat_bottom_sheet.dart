import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {'text': text, 'isUser': isUser};

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(text: json['text'], isUser: json['isUser']);
  }
}

class AiChatBottomSheet extends StatefulWidget {
  const AiChatBottomSheet({super.key});

  @override
  State<AiChatBottomSheet> createState() => _AiChatBottomSheetState();
}

class _AiChatBottomSheetState extends State<AiChatBottomSheet> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final Dio _dio = Dio();
  final Uuid _uuid = const Uuid();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final List<Map<String, String>> _chatHistory = [];

  String _currentSessionId = '';
  Map<String, List<ChatMessage>> _allChatSessions = {};
  Map<String, String> _customChatTitles = {};

  static const String _storageKey = 'gear_up_multi_chats_v3';
  static const String _titlesStorageKey = 'gear_up_chat_titles_v1';

  @override
  void initState() {
    super.initState();
    _loadAllChats();
  }

  Future<void> _loadAllChats() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString(_storageKey);
    final String? savedTitles = prefs.getString(_titlesStorageKey);

    if (savedTitles != null) {
      _customChatTitles = Map<String, String>.from(jsonDecode(savedTitles));
    }

    if (savedData != null) {
      final Map<String, dynamic> decodedMap = jsonDecode(savedData);
      _allChatSessions = decodedMap.map((key, value) {
        final list = (value as List).map((item) => ChatMessage.fromJson(item)).toList();
        return MapEntry(key, list);
      });

      if (_allChatSessions.isNotEmpty) {
        _currentSessionId = _allChatSessions.keys.last;
        _messages = _allChatSessions[_currentSessionId]!;
      } else {
        _createNewSession();
      }
    } else {
      _createNewSession();
    }

    _syncApiHistory();
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  Future<void> _saveAllChats() async {
    if (_messages.length > 50) {
      _messages.removeRange(0, _messages.length - 50);
    }
    _allChatSessions[_currentSessionId] = List.from(_messages);

    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> mapToSave = _allChatSessions.map((key, value) {
      return MapEntry(key, value.map((m) => m.toJson()).toList());
    });

    await prefs.setString(_storageKey, jsonEncode(mapToSave));
    await prefs.setString(_titlesStorageKey, jsonEncode(_customChatTitles));
    _syncApiHistory();
  }

  void _createNewSession() {
    setState(() {
      _currentSessionId = _uuid.v4();
      _messages = [];
      _allChatSessions[_currentSessionId] = [];
    });
    _syncApiHistory();
  }

  void _switchSession(String sessionId) {
    setState(() {
      _currentSessionId = sessionId;
      _messages = _allChatSessions[sessionId]!;
    });
    _syncApiHistory();
    _scrollToBottom();
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _deleteSession(String sessionId) async {
    _allChatSessions.remove(sessionId);
    _customChatTitles.remove(sessionId);

    if (_allChatSessions.isEmpty) {
      _createNewSession();
    } else if (_currentSessionId == sessionId) {
      _currentSessionId = _allChatSessions.keys.last;
      _messages = _allChatSessions[_currentSessionId]!;
    }

    await _saveAllChats();
    setState(() {});
  }

  void _shareSession(BuildContext context, String sessionId) {
    final msgs = _allChatSessions[sessionId] ?? [];
    if (msgs.isEmpty) return;

    String header = AppLang.tr(context, 'share_header') ?? "المحادثة مع جير أب:\n\n";
    String youText = AppLang.tr(context, 'you') ?? "أنت";
    String assistantText = AppLang.tr(context, 'assistant') ?? "الذكاء الاصطناعي";

    String chatText = header;
    for (var m in msgs) {
      chatText += "${m.isUser ? youText : assistantText}:\n${m.text}\n\n";
    }

    Clipboard.setData(ClipboardData(text: chatText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLang.tr(context, 'chat_copied_success') ?? "تم النسخ"), backgroundColor: AppColors.primary),
    );
  }

  void _showRenameDialog(String sessionId, String currentTitle, bool isDark) {
    TextEditingController renameController = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLang.tr(context, 'rename_chat_title') ?? "تغيير الاسم", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: renameController,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: AppLang.tr(context, 'type_new_name') ?? "اكتب الاسم الجديد",
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLang.tr(context, 'cancel') ?? "إلغاء", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              if (renameController.text.trim().isNotEmpty) {
                setState(() {
                  _customChatTitles[sessionId] = renameController.text.trim();
                });
                _saveAllChats();
                Navigator.pop(ctx);
                _scaffoldKey.currentState?.closeDrawer();
              }
            },
            child: Text(AppLang.tr(context, 'save') ?? "حفظ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(int index) async {
    _messageController.text = _messages[index].text;
    setState(() {
      _messages.removeRange(index, _messages.length);
    });
    await _saveAllChats();
    _focusNode.requestFocus();
  }

  void _syncApiHistory() {
    _chatHistory.clear();
    _chatHistory.add({
      "role": "system",
      "content": "You are an expert automotive AI assistant for the 'Gear Up' app. "
          "CRITICAL RULES FOR ARABIC RESPONSES: "
          "1. ALWAYS reply in natural, friendly Egyptian Arabic (العامية المصرية الدارجة). "
          "2. DO NOT mix English words in the middle of an Arabic sentence unless it is absolutely necessary (like a car brand 'BMW'). "
          "3. Structure your response clearly using simple line breaks. DO NOT use complex markdown formats like tables. "
          "4. Maintain a perfect Right-to-Left (RTL) reading flow. Keep numbers and English words properly isolated so the sentence doesn't break. "
          "If the user asks in English, reply in English normally. Be concise and highly professional."
    });

    for (var msg in _messages) {
      _chatHistory.add({
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.text
      });
    }
  }

  // 🔥 دالة الإرسال المتأمنة اللي بتكلم سيرفرك 🔥
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    await _saveAllChats();

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _dio.post(
        'https://d897c33f-6257-4a85-9126-2bc9c6be829e-00-dd6nn6kccr87.spock.replit.dev/api/ai/openrouter-chat',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true,
        ),
        data: {
          "messages": _chatHistory,
        },
      );

      if (response.statusCode == 200) {
        final aiText = response.data['choices'][0]['message']['content'];

        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(text: aiText, isUser: false));
            _isLoading = false;
          });
          await _saveAllChats();
          _scrollToBottom();
        }
      } else {
        throw Exception('Server Error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: AppLang.tr(context, 'connection_error') ?? 'حدث خطأ في الاتصال، حاول مرة أخرى', isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
      _messages.removeLast(); // اختياري عشان ميحفظش الخطأ
      await _saveAllChats();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showDeleteConfirmation(BuildContext context, String sessionId, bool isDark) {
    String successMsg = AppLang.tr(context, 'chat_deleted_success') ?? "تم الحذف";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Text(AppLang.tr(context, 'delete_confirmation_title') ?? "تأكيد الحذف", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          AppLang.tr(context, 'delete_confirmation_desc') ?? "هل أنت متأكد من حذف هذه المحادثة؟",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLang.tr(context, 'cancel') ?? "إلغاء", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSession(sessionId);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg), backgroundColor: Colors.redAccent));
            },
            child: Text(AppLang.tr(context, 'yes_delete') ?? "نعم، احذف", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final activeSessions = _allChatSessions.entries.where((e) => e.value.isNotEmpty).toList();

    String shareText = AppLang.tr(context, 'share_chat') ?? (isRtl ? 'مشاركة المحادثة' : 'Share Chat');

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: true,

            drawer: Drawer(
              backgroundColor: isDark ? const Color(0xFF191919) : const Color(0xFFF9F9FB),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(top: 50, bottom: 24),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF1E3A5F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.history, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text(AppLang.tr(context, 'chat_history') ?? "السجل", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    leading: Icon(Icons.add_circle_outline, color: isDark ? Colors.white60 : Colors.black54, size: 24),
                    title: Text(
                        AppLang.tr(context, 'new_chat') ?? "محادثة جديدة",
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.w600, fontSize: 15)
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _createNewSession();
                    },
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: activeSessions.isEmpty
                        ? Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                        const SizedBox(height: 16),
                        Text(AppLang.tr(context, 'no_previous_chats') ?? "لا يوجد محادثات", style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
                      ],
                    ))
                        : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      itemCount: activeSessions.length,
                      itemBuilder: (context, index) {
                        final session = activeSessions[index];
                        final isCurrent = session.key == _currentSessionId;
                        final title = _customChatTitles[session.key] ?? session.value.first.text;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                              color: isCurrent ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isCurrent ? AppColors.primary.withOpacity(0.2) : Colors.transparent)
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(left: 8, right: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isCurrent ? AppColors.primary : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
                              child: Icon(Icons.chat_bubble_outline, color: isCurrent ? Colors.white : (isDark ? Colors.white54 : Colors.black54), size: 16),
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500, fontSize: 14),
                            ),
                            onTap: () => _switchSession(session.key),

                            trailing: PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : Colors.black54, size: 20),
                              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                              elevation: 8,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onSelected: (value) {
                                if (value == 'share') {
                                  _shareSession(context, session.key);
                                } else if (value == 'rename') {
                                  _showRenameDialog(session.key, title, isDark);
                                } else if (value == 'delete') {
                                  _showDeleteConfirmation(context, session.key, isDark);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.edit_outlined, color: Colors.blue, size: 16)),
                                      const SizedBox(width: 12),
                                      Text(AppLang.tr(context, 'rename_chat') ?? "تعديل", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.share_outlined, color: AppColors.primary, size: 16)),
                                      const SizedBox(width: 12),
                                      Text(shareText, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16)),
                                      const SizedBox(width: 12),
                                      Text(AppLang.tr(context, 'delete_chat') ?? "حذف", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            body: Container(
              decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 25, spreadRadius: 5),
                  ]
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF1E3A5F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLang.tr(context, 'ai_title') ?? "مساعد Gear Up", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                Text(AppLang.tr(context, 'always_here_to_help') ?? "دائماً هنا للمساعدة", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF252525) : Colors.white,
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(24),
                                            topRight: const Radius.circular(24),
                                            bottomRight: isRtl ? Radius.zero : const Radius.circular(24),
                                            bottomLeft: isRtl ? const Radius.circular(24) : Radius.zero,
                                          ),
                                        ),
                                        child: Text(
                                          AppLang.tr(context, 'ai_greeting') ?? "مرحباً! كيف يمكنني مساعدتك؟",
                                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, height: 1.6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              if (_messages.isEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(AppLang.tr(context, 'quick_suggestions') ?? "اقتراحات", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: _buildPremiumSuggestionCard(AppLang.tr(context, 'sugg_title_1') ?? "", AppLang.tr(context, 'sugg_desc_1') ?? "قارنلي بين توسان وسبورتاج", Icons.newspaper_rounded, isDark)),
                                          const SizedBox(width: 12),
                                          Expanded(child: _buildPremiumSuggestionCard(AppLang.tr(context, 'sugg_title_2') ?? "", AppLang.tr(context, 'sugg_desc_2') ?? "إيه أرخص عربية جديدة؟", Icons.build_circle_outlined, isDark)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(child: _buildPremiumSuggestionCard(AppLang.tr(context, 'sugg_title_3') ?? "", AppLang.tr(context, 'sugg_desc_3') ?? "عربيتي بتسحب بنزين، إيه الحل؟", Icons.shopping_bag_outlined, isDark)),
                                          const SizedBox(width: 12),
                                          Expanded(child: _buildPremiumSuggestionCard(AppLang.tr(context, 'sugg_title_4') ?? "", AppLang.tr(context, 'sugg_desc_4') ?? "إزاي أبيع عربيتي بسرعة؟", Icons.compare_arrows_rounded, isDark)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        }

                        final actualIndex = index - 1;
                        final msg = _messages[actualIndex];

                        bool isArabicMsg = RegExp(r'[\u0600-\u06FF]').hasMatch(msg.text);

                        return Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Row(
                            mainAxisAlignment: msg.isUser
                                ? (isRtl ? MainAxisAlignment.start : MainAxisAlignment.end)
                                : (isRtl ? MainAxisAlignment.end : MainAxisAlignment.start),
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!msg.isUser) ...[
                                CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                              ],

                              Flexible(
                                child: Column(
                                  crossAxisAlignment: msg.isUser
                                      ? (isRtl ? CrossAxisAlignment.start : CrossAxisAlignment.end)
                                      : (isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start),
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        gradient: msg.isUser ? const LinearGradient(colors: [AppColors.primary, Color(0xFF1E3A5F)]) : null,
                                        color: msg.isUser ? null : (isDark ? const Color(0xFF252525) : Colors.white),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(24),
                                          topRight: const Radius.circular(24),
                                          bottomLeft: msg.isUser
                                              ? (isRtl ? Radius.zero : const Radius.circular(24))
                                              : (isRtl ? const Radius.circular(24) : Radius.zero),
                                          bottomRight: msg.isUser
                                              ? (isRtl ? const Radius.circular(24) : Radius.zero)
                                              : (isRtl ? Radius.zero : const Radius.circular(24)),
                                        ),
                                      ),
                                      child: Text(
                                        msg.text,
                                        textDirection: isArabicMsg ? TextDirection.rtl : TextDirection.ltr,
                                        style: TextStyle(
                                            color: msg.isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                            fontSize: 15,
                                            height: 1.6
                                        ),
                                      ),
                                    ),
                                    if (msg.isUser) ...[
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () => _editMessage(actualIndex),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.edit_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                                              const SizedBox(width: 4),
                                              Text(AppLang.tr(context, 'edit') ?? "تعديل", style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      )
                                    ]
                                  ],
                                ),
                              ),

                              if (msg.isUser) ...[
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                                  child: Icon(Icons.person_outline, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF252525) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                                const SizedBox(width: 12),
                                Text(AppLang.tr(context, 'ai_thinking') ?? "بفكر...", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1),
                            ),
                            child: TextField(
                              controller: _messageController,
                              focusNode: _focusNode,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (value) => _sendMessage(value),
                              decoration: InputDecoration(
                                hintText: AppLang.tr(context, 'type_message') ?? "اكتب رسالتك...",
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _sendMessage(_messageController.text),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [AppColors.primary, Color(0xFF1E3A5F)]),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                                isRtl ? Icons.send_rounded : Icons.send,
                                color: Colors.white,
                                size: 20
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumSuggestionCard(String title, String desc, IconData icon, bool isDark) {
    return GestureDetector(
      onTap: () => _sendMessage(desc),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFEEEEEE)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isDark ? Colors.white54 : AppColors.textHint, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}