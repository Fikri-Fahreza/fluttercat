import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final Dio _dio = Dio();
  
  // Navigation Tabs
  String _activeTab = 'chats'; // chats, friends, requests
  String _chatsSubTab = 'pribadi'; // pribadi, grup

  // Data lists
  List<dynamic> _friends = [];
  List<dynamic> _requests = [];
  List<dynamic> _groups = [];
  List<dynamic> _messages = [];

  bool _isLoading = true;
  bool _isRefreshing = false;

  // Add friend
  final TextEditingController _addFriendController = TextEditingController();
  bool _isAddingFriend = false;

  // Create Group
  final TextEditingController _groupNameController = TextEditingController();
  final Set<String> _selectedMembers = {};
  bool _isCreatingGroup = false;

  // Active Chat Session
  Map<String, dynamic>? _activeChatFriend;
  Map<String, dynamic>? _activeChatGroup;
  final TextEditingController _messageController = TextEditingController();
  bool _isSendingMsg = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _addFriendController.dispose();
    _groupNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'});

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _dio.get('${ApiConfig.baseUrl}/api/friends', options: _authOptions),
        _dio.get('${ApiConfig.baseUrl}/api/friend-requests', options: _authOptions),
        _dio.get('${ApiConfig.baseUrl}/api/groups', options: _authOptions),
      ]);

      if (mounted) {
        setState(() {
          _friends = results[0].data['friends'] ?? [];
          _requests = results[1].data['requests'] ?? [];
          _groups = results[2].data['groups'] ?? [];
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch Social Data Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_activeChatFriend != null) {
        _fetchMessages(_activeChatFriend!['id'].toString(), silent: true);
      } else if (_activeChatGroup != null) {
        _fetchGroupMessages(_activeChatGroup!['id'].toString(), silent: true);
      } else {
        _fetchData();
      }
    });
  }

  Future<void> _fetchMessages(String friendId, {bool silent = false}) async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/messages/$friendId', options: _authOptions);
      if (mounted) {
        setState(() {
          _messages = res.data['messages'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchGroupMessages(String groupId, {bool silent = false}) async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/groups/$groupId/messages', options: _authOptions);
      if (mounted) {
        setState(() {
          _messages = res.data['messages'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMsg) return;

    setState(() {
      _isSendingMsg = true;
      _messageController.clear();
    });

    try {
      if (_activeChatFriend != null) {
        final res = await _dio.post(
          '${ApiConfig.baseUrl}/api/messages',
          data: {
            'receiver_id': _activeChatFriend!['id'],
            'message': text,
          },
          options: _authOptions,
        );
        setState(() {
          _messages.add(res.data['chat']);
        });
      } else if (_activeChatGroup != null) {
        final res = await _dio.post(
          '${ApiConfig.baseUrl}/api/groups/${_activeChatGroup!['id']}/messages',
          data: {'message': text},
          options: _authOptions,
        );
        setState(() {
          _messages.add(res.data['chat']);
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim pesan.')),
      );
    }
    setState(() => _isSendingMsg = false);
  }

  Future<void> _sendFriendRequest() async {
    final username = _addFriendController.text.trim();
    if (username.isEmpty || _isAddingFriend) return;

    setState(() => _isAddingFriend = true);
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/friend-requests',
        data: {'username': username},
        options: _authOptions,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.data['message'] ?? 'Permintaan pertemanan dikirim!')),
      );
      _addFriendController.clear();
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User tidak ditemukan atau sudah berteman.')),
      );
    }
    setState(() => _isAddingFriend = false);
  }

  Future<void> _respondRequest(int requestId, bool accept) async {
    final endpoint = accept ? 'accept' : 'decline';
    try {
      if (accept) {
        await _dio.put('${ApiConfig.baseUrl}/api/friend-requests/$requestId/accept', data: {}, options: _authOptions);
      } else {
        await _dio.delete('${ApiConfig.baseUrl}/api/friend-requests/$requestId/decline', options: _authOptions);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Permintaan diterima!' : 'Permintaan ditolak.')),
      );
      _fetchData();
    } catch (_) {}
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty || _selectedMembers.isEmpty || _isCreatingGroup) return;

    setState(() => _isCreatingGroup = true);
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/api/groups',
        data: {
          'name': name,
          'member_usernames': _selectedMembers.toList(),
        },
        options: _authOptions,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grup berhasil dibuat!')),
      );
      _groupNameController.clear();
      _selectedMembers.clear();
      Navigator.pop(context);
      _fetchData();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat grup.')),
      );
    }
    setState(() => _isCreatingGroup = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_activeChatFriend != null || _activeChatGroup != null) {
      return _buildChatSessionView();
    }

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: SafeArea(
        child: Column(
          children: [
            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Teman & Obrolan',
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textBrown),
                  ),
                  if (_activeTab == 'requests' && _requests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                      child: Text('${_requests.length}', style: GoogleFonts.nunito(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),

            // Top Tabs
            Row(
              children: [
                _tabHeaderItem('chats', 'OBROLAN'),
                _tabHeaderItem('friends', 'DAFTAR TEMAN'),
                _tabHeaderItem('requests', 'PERMINTAAN'),
              ],
            ),
            const Divider(color: AppColors.borderCream, height: 1),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                  : RefreshIndicator(
                      color: AppColors.primaryGreen,
                      onRefresh: _fetchData,
                      child: _buildActiveTabContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabHeaderItem(String tab, String label) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primaryGreen : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? AppColors.primaryGreen : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 'friends':
        return _buildFriendsTab();
      case 'requests':
        return _buildRequestsTab();
      default:
        return _buildChatsTab();
    }
  }

  Widget _buildChatsTab() {
    return Column(
      children: [
        // Sub-tabs Pribadi / Grup
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              _subTabChip('pribadi', 'Obrolan Pribadi'),
              const SizedBox(width: 8),
              _subTabChip('grup', 'Grup Chat'),
              const Spacer(),
              if (_chatsSubTab == 'grup')
                IconButton(
                  icon: const Icon(Icons.group_add, color: AppColors.primaryGreen),
                  onPressed: _showCreateGroupDialog,
                ),
            ],
          ),
        ),

        Expanded(
          child: _chatsSubTab == 'pribadi'
              ? _friends.isEmpty
                  ? _buildEmptyState('Belum ada obrolan.', 'Cari teman di tab "Daftar Teman" untuk memulai chat.')
                  : ListView.builder(
                      itemCount: _friends.length,
                      itemBuilder: (context, index) {
                        final friend = _friends[index];
                        return _buildChatRow(friend, false);
                      },
                    )
              : _groups.isEmpty
                  ? _buildEmptyState('Belum ada grup chat.', 'Buat grup baru dengan menekan tombol + di kanan atas.')
                  : ListView.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return _buildChatRow(group, true);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _subTabChip(String subTab, String label) {
    final isActive = _chatsSubTab == subTab;
    return GestureDetector(
      onTap: () => setState(() => _chatsSubTab = subTab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppColors.primaryGreen : AppColors.borderCream),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: isActive ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Widget _buildChatRow(Map<String, dynamic> item, bool isGroup) {
    final name = item['name'] ?? 'Chat';
    final sub = isGroup ? 'Grup Chat' : '@${item['username']}';
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.lightGreen,
        backgroundImage: (!isGroup && item['avatar'] != null) ? NetworkImage(_buildImageUrl(item['avatar'])) : null,
        child: (isGroup || item['avatar'] == null)
            ? Text(
                isGroup ? '👥' : '🐱',
                style: const TextStyle(fontSize: 16),
              )
            : null,
      ),
      title: Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown)),
      subtitle: Text(sub, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
      onTap: () {
        setState(() {
          if (isGroup) {
            _activeChatGroup = item;
            _activeChatFriend = null;
          } else {
            _activeChatFriend = item;
            _activeChatGroup = null;
          }
          _messages = [];
        });
        _startPolling();
        if (isGroup) {
          _fetchGroupMessages(item['id'].toString());
        } else {
          _fetchMessages(item['id'].toString());
        }
      },
    );
  }

  Future<void> _confirmDeleteFriend(Map<String, dynamic> friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardCream,
        title: Text('Hapus Pertemanan', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown)),
        content: Text('Yakin ingin menghapus ${friend['name']} dari daftar teman?', style: GoogleFonts.nunito(color: AppColors.textBrown)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.nunito(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final friendshipId = friend['friendship_id'];
        await _dio.delete(
          '${ApiConfig.baseUrl}/api/friend-requests/$friendshipId/decline',
          options: _authOptions,
        );
        setState(() {
          _friends.removeWhere((f) => f['friendship_id'] == friendshipId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pertemanan berhasil dihapus.')),
        );
      } catch (e) {
        debugPrint('Delete friend error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus pertemanan.')),
        );
      }
    }
  }

  Widget _buildFriendsTab() {
    return Column(
      children: [
        // Add friend field
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addFriendController,
                  style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
                  decoration: InputDecoration(
                    hintText: 'Masukkan username teman...',
                    fillColor: AppColors.cardCream,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isAddingFriend ? null : _sendFriendRequest,
                child: _isAddingFriend ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Tambah'),
              ),
            ],
          ),
        ),

        Expanded(
          child: _friends.isEmpty
              ? _buildEmptyState('Daftar teman kosong.', 'Tambah teman baru dengan memasukkan username mereka di atas.')
              : ListView.builder(
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.lightGreen,
                        backgroundImage: (friend['avatar'] != null) ? NetworkImage(_buildImageUrl(friend['avatar'])) : null,
                        child: (friend['avatar'] == null)
                            ? Text(
                                (friend['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                              )
                            : null,
                      ),
                      title: Text(friend['name'] ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown)),
                      subtitle: Text('@${friend['username'] ?? ''}', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primaryGreen),
                            onPressed: () {
                              setState(() {
                                _activeChatFriend = friend;
                                _activeChatGroup = null;
                                _messages = [];
                              });
                              _startPolling();
                              _fetchMessages(friend['id'].toString());
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_remove_outlined, color: AppColors.danger),
                            onPressed: () => _confirmDeleteFriend(friend),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    return _requests.isEmpty
        ? _buildEmptyState('Tidak ada permintaan pertemanan.', 'Semua permintaan pertemanan baru akan muncul di halaman ini.')
        : ListView.builder(
            itemCount: _requests.length,
            itemBuilder: (context, index) {
              final req = _requests[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.lightGreen,
                  child: Text('🐾'),
                ),
                title: Text(req['name'] ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown)),
                subtitle: Text('@${req['username'] ?? ''}', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: AppColors.primaryGreen),
                      onPressed: () => _respondRequest(req['id'], true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: AppColors.danger),
                      onPressed: () => _respondRequest(req['id'], false),
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildEmptyState(String title, String sub) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💬', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 10),
                  Text(title, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBrown)),
                  const SizedBox(height: 4),
                  Text(sub, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted), textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        );
      }
    );
  }

  // Active Chat UI
  Widget _buildChatSessionView() {
    final title = _activeChatFriend != null ? _activeChatFriend!['name'] : _activeChatGroup!['name'];
    final subtitle = _activeChatFriend != null ? '@${_activeChatFriend!['username']}' : 'Grup Chat';

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: GoogleFonts.nunito(fontSize: 11, color: Colors.white70)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _pollingTimer?.cancel();
            setState(() {
              _activeChatFriend = null;
              _activeChatGroup = null;
            });
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[_messages.length - 1 - index];
                final isMe = msg['sender'] == 'me' || msg['sender_id'] == context.read<AuthProvider>().user?['id'];
                
                return _buildMessageBubble(msg, isMe);
              },
            ),
          ),
          
          // Chat Input Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.cardCream,
              border: Border(top: BorderSide(color: AppColors.borderCream)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      fillColor: AppColors.bgCream,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primaryGreen),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text'] ?? msg['message'] ?? '';
    final time = msg['time'] ?? '';
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryGreen : AppColors.cardCream,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: Border.all(color: isMe ? AppColors.primaryGreen : AppColors.borderCream),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && msg['sender_name'] != null)
              Text(
                msg['sender_name'],
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
              ),
            Text(
              text,
              style: GoogleFonts.nunito(
                color: isMe ? Colors.white : AppColors.textBrown,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: GoogleFonts.nunito(
                  color: isMe ? Colors.white60 : AppColors.textMuted,
                  fontSize: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Create Group Modal Dialog
  void _showCreateGroupDialog() {
    _groupNameController.clear();
    _selectedMembers.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('👥 Buat Grup Baru', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama Grup:', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textBrown)),
              const SizedBox(height: 6),
              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(hintText: 'Nama grup...'),
              ),
              const SizedBox(height: 12),
              Text('Pilih Anggota:', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textBrown)),
              const SizedBox(height: 6),
              Container(
                height: 120,
                width: double.maxFinite,
                decoration: BoxDecoration(border: Border.all(color: AppColors.borderCream), borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    final username = friend['username'].toString();
                    final isChecked = _selectedMembers.contains(username);
                    return CheckboxListTile(
                      dense: true,
                      title: Text(friend['name'] ?? ''),
                      value: isChecked,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            _selectedMembers.add(username);
                          } else {
                            _selectedMembers.remove(username);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: GoogleFonts.nunito(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: _isCreatingGroup ? null : _createGroup,
              child: const Text('Buat'),
            ),
          ],
        ),
      ),
    );
  }
}
