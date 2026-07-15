class ApiConfig {
  static const String baseUrl = 'https://random.ezaneproject.my.id/meowbackend/public';

  // Auth
  static const String login = '/api/login';
  static const String register = '/api/register';
  static const String logout = '/api/logout';
  static const String me = '/api/me';

  // Cats
  static const String cats = '/api/cats';
  static String catDetail(int id) => '/api/cats/$id';
  static String deleteCat(int id) => '/api/cats/$id';

  // Feed & Posts
  static const String posts = '/api/posts';
  static String likePost(int id) => '/api/posts/$id/like';
  static String commentPost(int id) => '/api/posts/$id/comment';

  // Cat of the Day
  static const String cotd = '/api/cat-of-the-day';

  // Challenges
  static const String challenges = '/api/challenges';

  // Leaderboard
  static const String leaderboard = '/api/leaderboard';

  // Achievements
  static const String achievements = '/api/achievements';

  // Friends
  static const String friends = '/api/friends';
  static const String friendRequests = '/api/friend-requests';
  static String acceptFriend(int id) => '/api/friend-requests/$id/accept';

  // Chat
  static const String chats = '/api/chats';
  static String chatMessages(int id) => '/api/chats/$id/messages';

  // Map
  static const String catMap = '/api/cats/map';

  // Encyclopedia
  static const String encyclopedia = '/api/encyclopedia';

  // Gifts
  static const String gifts = '/api/gifts';
}
