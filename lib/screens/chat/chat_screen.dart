import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
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

  // Redesign additional variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, String> _lastMessages = {};
  final Map<String, String> _lastMessageTimes = {};
  final Map<String, int> _clearedMaxIds = {};

  // Cat Share variables
  List<dynamic> _myCats = [];
  bool _isLoadingCats = false;

  // Emoji Picker variables
  bool _showEmojiPicker = false;
  final List<String> _emojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
    '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
    '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🥸',
    '🐈', '🐱', '🐾', '🦁', '🐯', '🐆', '🐴', '🦄', '🦓', '🦌',
    '🐶', '🐺', '🦊', '🦝', '🐻', '🐼', '🦘', '🦡', '🐨', '🐷',
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '✊', '👊',
    '🔥', '✨', '🎉', '❤️', '🌟', '💡', '💯', '💬', '🔔', '📌'
  ];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageTextChanged);
    _fetchData();
    _startPolling();
  }

  void _onMessageTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _addFriendController.dispose();
    _groupNameController.dispose();
    _messageController.dispose();
    _searchController.dispose();
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

        // Fetch last message for each friend and group in background
        for (var friend in _friends) {
          _fetchLastMessage(friend['id'].toString());
        }
        for (var group in _groups) {
          _fetchGroupLastMessage(group['id'].toString());
        }
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

  Future<void> _fetchLastMessage(String friendId) async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/messages/$friendId', options: _authOptions);
      final msgs = res.data['messages'] ?? [];
      if (msgs.isNotEmpty && mounted) {
        final lastMsg = msgs.last;
        setState(() {
          final text = lastMsg['text'] ?? lastMsg['message'] ?? '';
          _lastMessages[friendId] = text.toString().startsWith('[CAT_SHARE]') ? 'Pamer Kucing! 🐾' : text;
          _lastMessageTimes[friendId] = lastMsg['time'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchGroupLastMessage(String groupId) async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/groups/$groupId/messages', options: _authOptions);
      final msgs = res.data['messages'] ?? [];
      if (msgs.isNotEmpty && mounted) {
        final lastMsg = msgs.last;
        setState(() {
          final text = lastMsg['text'] ?? lastMsg['message'] ?? '';
          _lastMessages['group_$groupId'] = text.toString().startsWith('[CAT_SHARE]') ? 'Pamer Kucing! 🐾' : text;
          _lastMessageTimes['group_$groupId'] = lastMsg['time'] ?? '';
        });
      }
    } catch (_) {}
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
        final list = res.data['messages'] ?? [];
        final clearedId = _clearedMaxIds[friendId] ?? 0;
        final filtered = list.where((msg) {
          final id = int.tryParse(msg['id']?.toString() ?? '') ?? 0;
          return id > clearedId;
        }).toList();
        setState(() {
          _messages = filtered;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchGroupMessages(String groupId, {bool silent = false}) async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/groups/$groupId/messages', options: _authOptions);
      if (mounted) {
        final list = res.data['messages'] ?? [];
        final key = 'group_$groupId';
        final clearedId = _clearedMaxIds[key] ?? 0;
        final filtered = list.where((msg) {
          final id = int.tryParse(msg['id']?.toString() ?? '') ?? 0;
          return id > clearedId;
        }).toList();
        setState(() {
          _messages = filtered;
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
        final friendId = _activeChatFriend!['id'].toString();
        final res = await _dio.post(
          '${ApiConfig.baseUrl}/api/messages',
          data: {
            'receiver_id': _activeChatFriend!['id'],
            'message': text,
          },
          options: _authOptions,
        );
        final chatMsg = res.data['chat'];
        chatMsg['read_status'] = 'delivered';
        setState(() {
          _messages.add(chatMsg);
          _lastMessages[friendId] = text;
          _lastMessageTimes[friendId] = chatMsg['time'] ?? '';
        });
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              final idx = _messages.indexWhere((m) => m['id'] == chatMsg['id']);
              if (idx != -1) {
                _messages[idx]['read_status'] = 'read';
              }
            });
          }
        });
      } else if (_activeChatGroup != null) {
        final groupId = _activeChatGroup!['id'].toString();
        final res = await _dio.post(
          '${ApiConfig.baseUrl}/api/groups/${_activeChatGroup!['id']}/messages',
          data: {'message': text},
          options: _authOptions,
        );
        final chatMsg = res.data['chat'];
        chatMsg['read_status'] = 'delivered';
        setState(() {
          _messages.add(chatMsg);
          _lastMessages['group_$groupId'] = text;
          _lastMessageTimes['group_$groupId'] = chatMsg['time'] ?? '';
        });
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              final idx = _messages.indexWhere((m) => m['id'] == chatMsg['id']);
              if (idx != -1) {
                _messages[idx]['read_status'] = 'read';
              }
            });
          }
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim pesan.')),
      );
    }
    setState(() => _isSendingMsg = false);
  }

  Future<void> _sendCatShareMessage(Map<String, dynamic> cat) async {
    final text = '[CAT_SHARE]${cat['custom_name']}|${cat['breed']}|${cat['rarity']}|${cat['photo_path']}';
    if (_isSendingMsg) return;

    setState(() {
      _isSendingMsg = true;
    });

    try {
      if (_activeChatFriend != null) {
        final friendId = _activeChatFriend!['id'].toString();
        final res = await _dio.post(
          '${ApiConfig.baseUrl}/api/messages',
          data: {
            'receiver_id': _activeChatFriend!['id'],
            'message': text,
          },
          options: _authOptions,
        );
        final chatMsg = res.data['chat'];
        chatMsg['read_status'] = 'delivered';
        setState(() {
          _messages.add(chatMsg);
          _lastMessages[friendId] = 'Pamer Kucing! 🐾';
          _lastMessageTimes[friendId] = chatMsg['time'] ?? '';
        });
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              final idx = _messages.indexWhere((m) => m['id'] == chatMsg['id']);
              if (idx != -1) {
                _messages[idx]['read_status'] = 'read';
              }
            });
          }
        });
      } else if (_activeChatGroup != null) {
        final groupId = _activeChatGroup!['id'].toString();
        final res = await _dio.post(
          '${ApiConfig.baseUrl}/api/groups/${_activeChatGroup!['id']}/messages',
          data: {'message': text},
          options: _authOptions,
        );
        final chatMsg = res.data['chat'];
        chatMsg['read_status'] = 'delivered';
        setState(() {
          _messages.add(chatMsg);
          _lastMessages['group_$groupId'] = 'Pamer Kucing! 🐾';
          _lastMessageTimes['group_$groupId'] = chatMsg['time'] ?? '';
        });
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              final idx = _messages.indexWhere((m) => m['id'] == chatMsg['id']);
              if (idx != -1) {
                _messages[idx]['read_status'] = 'read';
              }
            });
          }
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim pameran kucing.')),
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
                    style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textBrown),
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

            // Top Tabs redone with icons
            Row(
              children: [
                _tabHeaderItem('chats', Icons.chat_bubble_rounded, 'OBROLAN'),
                _tabHeaderItem('friends', Icons.people_alt_rounded, 'TEMAN'),
                _tabHeaderItem('requests', Icons.person_add_alt_1_rounded, 'PERMINTAAN'),
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

  Widget _tabHeaderItem(String tab, IconData icon, String label) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = tab;
            _searchQuery = '';
            _searchController.clear();
          });
        },
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? AppColors.primaryGreen : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? AppColors.primaryGreen : AppColors.textMuted,
                ),
              ),
            ],
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
    // Filter logic
    final filteredFriends = _friends.where((friend) {
      final name = (friend['name'] ?? '').toString().toLowerCase();
      final username = (friend['username'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || username.contains(_searchQuery.toLowerCase());
    }).toList();

    final filteredGroups = _groups.where((group) {
      final name = (group['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

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

        // Search Bar (WhatsApp-style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardCream,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderCream),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
              decoration: InputDecoration(
                hintText: _chatsSubTab == 'pribadi' ? 'Cari teman...' : 'Cari grup...',
                hintStyle: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _chatsSubTab == 'pribadi'
              ? filteredFriends.isEmpty
                  ? _buildEmptyState('Belum ada obrolan.', 'Cari teman di tab "Daftar Teman" untuk memulai chat.')
                  : ListView.builder(
                      itemCount: filteredFriends.length,
                      itemBuilder: (context, index) {
                        final friend = filteredFriends[index];
                        return _buildChatRow(friend, false);
                      },
                    )
              : filteredGroups.isEmpty
                  ? _buildEmptyState('Belum ada grup chat.', 'Buat grup baru dengan menekan tombol + di kanan atas.')
                  : ListView.builder(
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
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
      onTap: () {
        setState(() {
          _chatsSubTab = subTab;
          _searchQuery = '';
          _searchController.clear();
        });
      },
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

  Widget _buildChatRow(Map<String, dynamic> item, bool isGroup) {
    final itemId = item['id'].toString();
    final key = isGroup ? 'group_$itemId' : itemId;
    final name = item['name'] ?? 'Chat';
    final username = item['username'] ?? '';
    
    final lastMsg = _lastMessages[key] ?? (isGroup ? 'Grup Chat Baru' : '@$username');
    final lastMsgTime = _lastMessageTimes[key] ?? '';
    final avatarUrl = (!isGroup && item['avatar'] != null) ? _buildImageUrl(item['avatar']) : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCream),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.lightGreen,
            border: Border.all(color: AppColors.borderCream, width: 1.5),
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.person, color: AppColors.primaryGreen),
                  )
                : Center(
                    child: Text(
                      isGroup ? '👥' : '🐱',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textBrown,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3.0),
          child: Text(
            lastMsg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastMsgTime.isNotEmpty)
              Text(
                lastMsgTime,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 6),
            if (lastMsgTime.isNotEmpty && _lastMessages[key] != null)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
          ],
        ),
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
            _fetchGroupMessages(itemId);
          } else {
            _fetchMessages(itemId);
          }
        },
      ),
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
    final filteredFriends = _friends.where((friend) {
      final name = (friend['name'] ?? '').toString().toLowerCase();
      final username = (friend['username'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || username.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Add friend field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addFriendController,
                  style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
                  decoration: InputDecoration(
                    hintText: 'Masukkan username teman...',
                    fillColor: AppColors.cardCream,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isAddingFriend ? null : _sendFriendRequest,
                child: _isAddingFriend
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Tambah', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),

        // Search bar for friends tab
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardCream,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderCream),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
              decoration: InputDecoration(
                hintText: 'Cari dalam daftar teman...',
                hintStyle: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: filteredFriends.isEmpty
              ? _buildEmptyState('Daftar teman kosong.', 'Tambah teman baru dengan memasukkan username mereka di atas.')
              : ListView.builder(
                  itemCount: filteredFriends.length,
                  itemBuilder: (context, index) {
                    final friend = filteredFriends[index];
                    final avatarUrl = friend['avatar'] != null ? _buildImageUrl(friend['avatar']) : '';
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lightGreen,
                          border: Border.all(color: AppColors.borderCream),
                        ),
                        child: ClipOval(
                          child: avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.person, color: AppColors.primaryGreen),
                                )
                              : Center(
                                  child: Text(
                                    (friend['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                  ),
                                ),
                        ),
                      ),
                      title: Text(friend['name'] ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown)),
                      subtitle: Text('@${friend['username'] ?? ''}', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryGreen),
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
                  child: Text('🐱'),
                ),
                title: Text(req['name'] ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown)),
                subtitle: Text('@${req['username'] ?? ''}', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen),
                      onPressed: () => _respondRequest(req['id'], true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_rounded, color: AppColors.danger),
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
                  const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(title, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBrown)),
                  const SizedBox(height: 6),
                  Text(sub, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted), textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        );
      }
    );
  }

  // Active Chat Session redone in premium WhatsApp-style
  Widget _buildChatSessionView() {
    final title = _activeChatFriend != null ? _activeChatFriend!['name'] : _activeChatGroup!['name'];
    final subtitle = _activeChatFriend != null ? '@${_activeChatFriend!['username']}' : 'Grup Chat';
    final avatarUrl = (_activeChatFriend != null && _activeChatFriend!['avatar'] != null)
        ? _buildImageUrl(_activeChatFriend!['avatar'])
        : '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _pollingTimer?.cancel();
        setState(() {
          _activeChatFriend = null;
          _activeChatGroup = null;
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE5DDD5), // Classic WhatsApp Background Color
        appBar: AppBar(
          elevation: 1.5,
          backgroundColor: AppColors.primaryGreen,
          iconTheme: const IconThemeData(color: Colors.white),
          leadingWidth: 70,
          leading: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                onPressed: () {
                  _pollingTimer?.cancel();
                  setState(() {
                    _activeChatFriend = null;
                    _activeChatGroup = null;
                  });
                },
              ),
            ],
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lightGreen,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(Icons.person, color: AppColors.primaryGreen),
                        )
                      : Center(
                          child: Text(
                            _activeChatGroup != null ? '👥' : '🐱',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _activeChatFriend != null ? 'Online' : subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (value) {
                if (value == 'profile') {
                  _showFriendProfileDialog();
                } else if (value == 'clear') {
                  _clearChatHistory();
                } else if (value == 'unfriend') {
                  _confirmUnfriendFromChat();
                } else if (value == 'group_info') {
                  _showGroupInfoDialog();
                }
              },
              itemBuilder: (BuildContext context) {
                if (_activeChatGroup != null) {
                  return [
                    const PopupMenuItem<String>(
                      value: 'group_info',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.textBrown, size: 18),
                          SizedBox(width: 8),
                          Text('Detail Grup'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_rounded, color: AppColors.textBrown, size: 18),
                          SizedBox(width: 8),
                          Text('Bersihkan Obrolan'),
                        ],
                      ),
                    ),
                  ];
                } else {
                  return [
                    const PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, color: AppColors.textBrown, size: 18),
                          SizedBox(width: 8),
                          Text('Lihat Profil'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_rounded, color: AppColors.textBrown, size: 18),
                          SizedBox(width: 8),
                          Text('Bersihkan Obrolan'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'unfriend',
                      child: Row(
                        children: [
                          Icon(Icons.person_remove_outlined, color: AppColors.danger, size: 18),
                          SizedBox(width: 8),
                          Text('Hapus Pertemanan', style: TextStyle(color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ];
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[_messages.length - 1 - index];
                  final isMe = msg['sender'] == 'me' || msg['sender_id'] == context.read<AuthProvider>().user?['id'];
                  return _buildMessageBubble(msg, isMe);
                },
              ),
            ),
            
            // Chat Input Row Capsule WhatsApp-style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _showEmojiPicker
                                  ? Icons.keyboard_rounded
                                  : Icons.sentiment_satisfied_alt_rounded,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () {
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                              });
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              onTap: () {
                                if (_showEmojiPicker) {
                                  setState(() {
                                    _showEmojiPicker = false;
                                  });
                                }
                              },
                              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textBrown),
                              maxLines: null,
                              decoration: InputDecoration(
                                hintText: 'Tulis pesan...',
                                hintStyle: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          // Paperclip button to share caught cats ("pamer kucing")
                          IconButton(
                            icon: const Icon(Icons.attach_file_rounded, color: AppColors.textMuted),
                            onPressed: _showShareCatBottomSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Separate Circular Send FAB
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGreen,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showEmojiPicker) _buildEmojiPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text'] ?? msg['message'] ?? '';
    final time = msg['time'] ?? '';
    
    // Render custom Cat Share Card bubble
    if (text.toString().startsWith('[CAT_SHARE]')) {
      return _buildCatShareBubble(text.toString(), time, isMe, msg);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE2F4D9) : Colors.white, // Soft green bubble for me, white for other
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(2), // WhatsApp asymmetric tail
            bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 1,
              offset: const Offset(0, 1),
            )
          ],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && msg['sender_name'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  msg['sender_name'],
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            
            // Text and Time/Checkmarks Layout
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                Text(
                  text,
                  style: GoogleFonts.nunito(
                    color: AppColors.textBrown,
                    fontSize: 13.5,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.nunito(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      _buildCheckmarks(msg),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatShareBubble(String rawText, String time, bool isMe, Map<String, dynamic> msg) {
    try {
      final parts = rawText.replaceFirst('[CAT_SHARE]', '').split('|');
      if (parts.length >= 4) {
        final customName = parts[0];
        final breed = parts[1];
        final rarity = parts[2];
        final photoPath = parts[3];
        final catPhoto = _buildImageUrl(photoPath);
        final rarityColor = _getRarityColor(rarity);
        
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            width: MediaQuery.of(context).size.width * 0.72,
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFE2F4D9) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(2),
                bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe && msg['sender_name'] != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                    child: Text(
                      msg['sender_name'],
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                
                // Cat Photo Card
                Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: catPhoto.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: catPhoto,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox(
                              height: 140,
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.pets, color: AppColors.primaryGreen),
                          )
                        : const SizedBox(
                            height: 140,
                            child: Center(child: Icon(Icons.pets, color: AppColors.primaryGreen)),
                          ),
                  ),
                ),
                
                // Details
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              customName,
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textBrown,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: rarityColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rarity,
                              style: GoogleFonts.nunito(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: rarityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '$breed • Pamer Kucing! 🐾',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: GoogleFonts.nunito(
                                  color: AppColors.textMuted,
                                  fontSize: 8.5,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 3),
                                _buildCheckmarks(msg),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {}
    
    // Fallback if parsing fails
    return const SizedBox.shrink();
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'Legendary':
        return const Color(0xFFE4C078); // soft gold
      case 'Epic':
        return Colors.purple;
      case 'Rare':
        return Colors.blue;
      default:
        return AppColors.primaryGreen; // Common
    }
  }

  String _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Widget _buildCheckmarks(Map<String, dynamic> msg) {
    final status = msg['read_status'] ?? 'read';
    if (status == 'sending') {
      return const Icon(
        Icons.done_rounded,
        size: 13,
        color: Colors.grey,
      );
    } else if (status == 'delivered') {
      return const Icon(
        Icons.done_all_rounded,
        size: 13,
        color: Colors.grey,
      );
    } else {
      return const Icon(
        Icons.done_all_rounded,
        size: 13,
        color: Color(0xFF53BDEB),
      );
    }
  }

  // Create Group Modal Dialog
  void _showCreateGroupDialog() {
    _groupNameController.clear();
    _selectedMembers.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.cardCream,
          title: Text('👥 Buat Grup Baru', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama Grup:', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textBrown)),
              const SizedBox(height: 6),
              TextField(
                controller: _groupNameController,
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
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
                      activeColor: AppColors.primaryGreen,
                      title: Text(friend['name'] ?? '', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown)),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              onPressed: _isCreatingGroup ? null : _createGroup,
              child: Text('Buat', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom sheet to select caught cat ("pamer kucing")
  void _showShareCatBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Load cats inside if empty
            if (_myCats.isEmpty && !_isLoadingCats) {
              _isLoadingCats = true;
              _dio.get('${ApiConfig.baseUrl}/api/cats', options: _authOptions).then((res) {
                if (mounted) {
                  setModalState(() {
                    _myCats = res.data['cats'] ?? [];
                    _isLoadingCats = false;
                  });
                }
              }).catchError((_) {
                if (mounted) {
                  setModalState(() {
                    _isLoadingCats = false;
                  });
                }
              });
            }

            return Container(
              height: 400,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderCream,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.pets_rounded, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Pamer Kucing Peliharaan',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoadingCats
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                        : _myCats.isEmpty
                            ? Center(
                                child: Text(
                                  'Kamu belum menangkap kucing. Ayo cari kucing terlebih dahulu!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(color: AppColors.textMuted),
                                ),
                              )
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: _myCats.length,
                                itemBuilder: (context, index) {
                                  final cat = _myCats[index];
                                  final catPhoto = _buildImageUrl(cat['photo_path']);
                                  final rarityColor = _getRarityColor(cat['rarity'] ?? 'Common');
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _sendCatShareMessage(cat);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.cardCream,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.borderCream),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                              child: catPhoto.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: catPhoto,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => const Center(
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                                                      ),
                                                      errorWidget: (context, url, error) => const Icon(Icons.pets, color: AppColors.primaryGreen),
                                                    )
                                                  : const Center(child: Icon(Icons.pets, color: AppColors.primaryGreen)),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  cat['custom_name'] ?? 'Kucing',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.nunito(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: AppColors.textBrown,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        cat['breed'] ?? 'Domestic Cat',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.nunito(
                                                          fontSize: 10,
                                                          color: AppColors.textMuted,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: rarityColor.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        cat['rarity'] ?? 'Common',
                                                        style: GoogleFonts.nunito(
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                          color: rarityColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    
    if (!selection.isValid || selection.baseOffset == selection.extentOffset) {
      _messageController.text = text + emoji;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    } else {
      final start = selection.start;
      final end = selection.end;
      final newText = text.replaceRange(start, end, emoji);
      _messageController.text = newText;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: start + emoji.length),
      );
    }
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 220,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _emojis.length,
        itemBuilder: (context, index) {
          final emoji = _emojis[index];
          return GestureDetector(
            onTap: () => _insertEmoji(emoji),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showFriendProfileDialog() async {
    if (_activeChatFriend == null) return;
    final friend = _activeChatFriend!;
    final avatarUrl = friend['avatar'] != null ? _buildImageUrl(friend['avatar']) : '';
    
    int? rank;
    int? score;
    int? catsCount;
    bool isLoadingStats = true;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (isLoadingStats) {
            _dio.get('${ApiConfig.baseUrl}/api/leaderboard', options: _authOptions).then((res) {
              final leaderboard = res.data['leaderboard'] as List<dynamic>;
              final match = leaderboard.firstWhere(
                (u) => u['id'].toString() == friend['id'].toString(),
                orElse: () => null,
              );
              if (mounted) {
                setModalState(() {
                  isLoadingStats = false;
                  if (match != null) {
                    rank = match['rank'];
                    score = match['total_score'];
                    catsCount = match['cats_count'];
                  }
                });
              }
            }).catchError((_) {
              if (mounted) {
                setModalState(() {
                  isLoadingStats = false;
                });
              }
            });
          }

          return AlertDialog(
            backgroundColor: AppColors.cardCream,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.lightGreen,
                    border: Border.all(color: AppColors.primaryGreen, width: 2),
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const Icon(Icons.person, size: 40, color: AppColors.primaryGreen),
                          )
                        : const Center(child: Text('🐱', style: TextStyle(fontSize: 40))),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  friend['name'] ?? 'Teman',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textBrown,
                  ),
                ),
                Text(
                  '@${friend['username']}',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: AppColors.borderCream),
                const SizedBox(height: 12),
                isLoadingStats
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildProfileStatColumn('Poin', score != null ? '$score' : '-'),
                          _buildProfileStatColumn('Rank', rank != null ? '#$rank' : '-'),
                          _buildProfileStatColumn('Kucing', catsCount != null ? '$catsCount' : '-'),
                        ],
                      ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmUnfriendFromChat();
                  },
                  icon: const Icon(Icons.person_remove_outlined, color: Colors.white, size: 18),
                  label: Text(
                    'Hapus Pertemanan',
                    style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmUnfriendFromChat() async {
    if (_activeChatFriend == null) return;
    final friend = _activeChatFriend!;
    final friendshipId = friend['friendship_id'];

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
        await _dio.delete(
          '${ApiConfig.baseUrl}/api/friend-requests/$friendshipId/decline',
          options: _authOptions,
        );
        if (mounted) {
          setState(() {
            _friends.removeWhere((f) => f['friendship_id'] == friendshipId);
            _activeChatFriend = null;
            _activeChatGroup = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pertemanan berhasil dihapus.')),
          );
        }
      } catch (e) {
        debugPrint('Delete friend error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus pertemanan.')),
        );
      }
    }
  }

  Future<void> _clearChatHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardCream,
        title: Text('Bersihkan Obrolan', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown)),
        content: Text('Apakah Anda yakin ingin membersihkan seluruh riwayat obrolan ini secara lokal?', style: GoogleFonts.nunito(color: AppColors.textBrown)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.nunito(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Bersihkan', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final key = _activeChatFriend != null
          ? _activeChatFriend!['id'].toString()
          : 'group_${_activeChatGroup!['id']}';
          
      int maxId = 0;
      for (var msg in _messages) {
        final id = int.tryParse(msg['id']?.toString() ?? '') ?? 0;
        if (id > maxId) maxId = id;
      }

      setState(() {
        _clearedMaxIds[key] = maxId;
        _messages.clear();
        _lastMessages[key] = _activeChatFriend != null ? '@${_activeChatFriend!['username']}' : 'Grup Chat Baru';
        _lastMessageTimes[key] = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Riwayat obrolan dibersihkan.')),
      );
    }
  }

  void _showGroupInfoDialog() {
    if (_activeChatGroup == null) return;
    final group = _activeChatGroup!;
    final List<dynamic> members = group['members'] ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Text(
              'Detail Grup',
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group['name'] ?? 'Nama Grup',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textBrown),
              ),
              const SizedBox(height: 4),
              Text(
                '${members.length} Anggota',
                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.borderCream),
              const SizedBox(height: 8),
              Text(
                'Anggota Grup:',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textBrown),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final memberAvatar = member['avatar'] != null ? _buildImageUrl(member['avatar']) : '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.lightGreen,
                        child: memberAvatar.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: memberAvatar,
                                  fit: BoxFit.cover,
                                  width: 32,
                                  height: 32,
                                  errorWidget: (context, url, error) => const Icon(Icons.person, size: 16, color: AppColors.primaryGreen),
                                ),
                              )
                            : const Text('🐱', style: TextStyle(fontSize: 14)),
                      ),
                      title: Text(
                        member['name'] ?? '',
                        style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBrown),
                      ),
                      subtitle: Text(
                        '@${member['username'] ?? ''}',
                        style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 40),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _leaveGroupChat();
                },
                icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 16),
                label: Text(
                  'Keluar dari Grup',
                  style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leaveGroupChat() async {
    if (_activeChatGroup == null) return;
    final groupId = _activeChatGroup!['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardCream,
        title: Text('Keluar dari Grup', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown)),
        content: Text('Apakah Anda yakin ingin keluar dari grup chat ini?', style: GoogleFonts.nunito(color: AppColors.textBrown)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.nunito(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Keluar', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dio.delete(
          '${ApiConfig.baseUrl}/api/groups/$groupId/leave',
          options: _authOptions,
        );
        if (mounted) {
          setState(() {
            _groups.removeWhere((g) => g['id'] == groupId);
            _activeChatFriend = null;
            _activeChatGroup = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anda telah keluar dari grup.')),
          );
        }
      } catch (e) {
        debugPrint('Leave group error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal keluar dari grup.')),
        );
      }
    }
  }
}
