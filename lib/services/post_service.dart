import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'account_service.dart';
import 'cloud/fs_mirror.dart';
import 'cloud/media_service.dart';

/// Who posted or commented.
class FeedAuthor {
  const FeedAuthor({
    required this.handle,
    required this.name,
    this.title = '',
    this.colorValue = 0xFF4F46E5,
    this.verified = false,
    this.isDemo = false,
  });

  final String handle;
  final String name;
  final String title;
  final int colorValue;
  final bool verified;

  /// Fictional sample account (shown with a small "Demo" label).
  final bool isDemo;

  String get initials {
    final parts = name
        .replaceAll('Dr. ', '')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final letters = parts.map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  Map<String, dynamic> toJson() => {
        'handle': handle,
        'name': name,
        'title': title,
        'color': colorValue,
        'verified': verified,
        'demo': isDemo,
      };

  factory FeedAuthor.fromJson(Map<String, dynamic> json) => FeedAuthor(
        handle: json['handle'] as String? ?? 'user',
        name: json['name'] as String? ?? 'User',
        // Older saved posts called regular members "Patient".
        title: (json['title'] as String? ?? '') == 'Patient'
            ? 'User'
            : json['title'] as String? ?? '',
        colorValue: json['color'] as int? ?? 0xFF4F46E5,
        verified: json['verified'] as bool? ?? false,
        isDemo: json['demo'] as bool? ?? false,
      );
}

class FeedComment {
  FeedComment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    Set<String>? likedBy,
    this.baseLikes = 0,
  }) : likedBy = likedBy ?? <String>{};

  final String id;
  final FeedAuthor author;
  final String text;
  final DateTime createdAt;
  final int baseLikes;
  final Set<String> likedBy;

  int get likes => baseLikes + likedBy.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author.toJson(),
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'baseLikes': baseLikes,
        'likedBy': likedBy.toList(),
      };

  factory FeedComment.fromJson(Map<String, dynamic> json) => FeedComment(
        id: json['id'] as String,
        author: FeedAuthor.fromJson(json['author'] as Map<String, dynamic>),
        text: json['text'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        baseLikes: json['baseLikes'] as int? ?? 0,
        likedBy: {...(json['likedBy'] as List<dynamic>? ?? []).cast<String>()},
      );
}

/// One animated slide of a health-tip reel.
///
/// [type] is one of: title, step, check, stat, breath, pulse, outro.
/// [icon] is a key looked up in the reel player's icon map.
class ReelSlide {
  const ReelSlide({
    required this.type,
    this.title = '',
    this.body = '',
    this.icon = 'heart',
    this.seconds = 3.5,
  });

  final String type;
  final String title;
  final String body;
  final String icon;
  final double seconds;

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'body': body,
        'icon': icon,
        'seconds': seconds,
      };

  factory ReelSlide.fromJson(Map<String, dynamic> json) => ReelSlide(
        type: json['type'] as String? ?? 'title',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        icon: json['icon'] as String? ?? 'heart',
        seconds: (json['seconds'] as num?)?.toDouble() ?? 3.5,
      );
}

class FeedPost {
  FeedPost({
    required this.id,
    required this.author,
    required this.image,
    required this.caption,
    required this.createdAt,
    this.isAsset = true,
    this.tall = false,
    this.topic = 'General',
    this.location = '',
    this.baseLikes = 0,
    this.kind = 'post',
    this.theme = 0,
    this.baseViews = 0,
    this.slides = const <ReelSlide>[],
    this.authorUid = '',
    Set<String>? likedBy,
    Set<String>? savedBy,
    Set<String>? viewedBy,
    List<FeedComment>? comments,
  })  : likedBy = likedBy ?? <String>{},
        savedBy = savedBy ?? <String>{},
        viewedBy = viewedBy ?? <String>{},
        comments = comments ?? <FeedComment>[];

  final String id;
  final FeedAuthor author;

  /// Asset path (sample posts) or a file path on this PC (uploads).
  final String image;
  final bool isAsset;

  /// Portrait image that looks best in the tall grid slot.
  final bool tall;
  final String caption;
  final String topic;
  final String location;
  final DateTime createdAt;
  final int baseLikes;
  final Set<String> likedBy;
  final Set<String> savedBy;
  final List<FeedComment> comments;

  /// "post" (photo) or "reel" (animated health-tip reel).
  final String kind;

  /// Reel colour theme (index into the reel player's palette).
  final int theme;
  final int baseViews;
  final Set<String> viewedBy;
  final List<ReelSlide> slides;

  /// Firebase user id of whoever posted it ('' for built-in demo posts).
  final String authorUid;

  bool get isReel => kind == 'reel';

  /// Built-in sample content (not something a user of this PC created).
  bool get isSample => id.startsWith('seed_') || id.startsWith('reel_');
  int get likes => baseLikes + likedBy.length;
  int get views => baseViews + viewedBy.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author.toJson(),
        'image': image,
        'isAsset': isAsset,
        'tall': tall,
        'caption': caption,
        'topic': topic,
        'location': location,
        'createdAt': createdAt.toIso8601String(),
        'baseLikes': baseLikes,
        'likedBy': likedBy.toList(),
        'savedBy': savedBy.toList(),
        'comments': comments.map((comment) => comment.toJson()).toList(),
        'kind': kind,
        'theme': theme,
        'baseViews': baseViews,
        'viewedBy': viewedBy.toList(),
        'slides': slides.map((slide) => slide.toJson()).toList(),
        'authorUid': authorUid,
      };

  factory FeedPost.fromJson(Map<String, dynamic> json) => FeedPost(
        id: json['id'] as String,
        author: FeedAuthor.fromJson(json['author'] as Map<String, dynamic>),
        image: json['image'] as String? ?? '',
        isAsset: json['isAsset'] as bool? ?? true,
        tall: json['tall'] as bool? ?? false,
        caption: json['caption'] as String? ?? '',
        topic: json['topic'] as String? ?? 'General',
        location: json['location'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        baseLikes: json['baseLikes'] as int? ?? 0,
        likedBy: {...(json['likedBy'] as List<dynamic>? ?? []).cast<String>()},
        savedBy: {...(json['savedBy'] as List<dynamic>? ?? []).cast<String>()},
        comments: [
          for (final item in json['comments'] as List<dynamic>? ?? [])
            FeedComment.fromJson(item as Map<String, dynamic>),
        ],
        kind: json['kind'] as String? ?? 'post',
        theme: json['theme'] as int? ?? 0,
        baseViews: json['baseViews'] as int? ?? 0,
        viewedBy: {...(json['viewedBy'] as List<dynamic>? ?? []).cast<String>()},
        slides: [
          for (final item in json['slides'] as List<dynamic>? ?? [])
            ReelSlide.fromJson(item as Map<String, dynamic>),
        ],
        authorUid: json['authorUid'] as String? ?? '',
      );
}

/// Explore feed: posts, likes, comments, saves and follows, stored on this PC.
/// Every signed-in user can upload a post.
class PostService extends ChangeNotifier {
  PostService._();

  static final PostService instance = PostService._();

  static const topics = [
    'General',
    'Heart',
    'Kids',
    'Nutrition',
    'Mind',
    'Rehab',
    'Skin',
    'First aid',
  ];

  final List<FeedPost> _postList = [];
  final List<_FollowDoc> _followDocs = [];
  late final FsMirror<FeedPost> _postMirror = FsMirror<FeedPost>(
    collection: 'posts',
    list: _postList,
    idOf: (post) => post.id,
    toJson: (post) => post.toJson(),
    fromJson: (id, json) => FeedPost.fromJson({...json, 'id': id}),
    onChange: () {
      _sort();
      notifyListeners();
    },
    write: _writePost,
  );
  late final FsMirror<_FollowDoc> _followMirror = FsMirror<_FollowDoc>(
    collection: 'follows',
    list: _followDocs,
    idOf: (doc) => doc.email,
    toJson: (doc) => doc.toJson(),
    fromJson: _FollowDoc.fromJson,
    onChange: notifyListeners,
  );
  bool _attached = false;

  List<FeedPost>? get _posts => _postList;

  bool get isLoaded => _attached;

  /// Everything, newest first.
  List<FeedPost> get posts => List.unmodifiable(_postList);

  List<FeedPost> get photoPosts =>
      posts.where((post) => !post.isReel).toList();

  List<FeedPost> get reels => posts.where((post) => post.isReel).toList();

  /// Distinct sample/other authors, for "Suggested for you" and stories.
  List<FeedAuthor> get authors {
    final seen = <String>{};
    return [
      for (final post in posts)
        if (seen.add(post.author.handle)) post.author,
    ];
  }

  /// Starts the live feed. The built-in health tips are added once, the
  /// first time anyone opens the feed.
  void attach(AppAccount me) {
    _attached = true;
    final db = FirebaseFirestore.instance;
    _postMirror.listen([db.collection('posts')]);
    _followMirror.listen([
      db.collection('follows').where(FieldPath.documentId, isEqualTo: me.email),
    ]);
    _postMirror.ready.then((_) => _addDemoContent());
  }

  void detach() {
    _attached = false;
    _postMirror.listen(const []);
    _followMirror.listen(const []);
  }

  Future<void> load() async {
    if (_attached) await _postMirror.ready;
  }

  Future<void> _addDemoContent() async {
    final ids = _postList.map((post) => post.id).toSet();
    final missing = [..._seedPosts(), ..._seedReels()]
        .where((post) => !ids.contains(post.id))
        .toList();
    if (missing.isEmpty) return;
    _postList.addAll(missing);
    _sort();
    await _postMirror.push();
    notifyListeners();
  }

  void _sort() =>
      _postList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> _changed() async {
    notifyListeners();
    await _postMirror.push();
    await _followMirror.push();
  }

  /// Likes, saves, views and new comments are merged on the server, so two
  /// people reacting at once don't undo each other.
  static void _writePost(
    WriteBatch batch,
    DocumentReference<JsonMap> ref,
    JsonMap now,
    JsonMap? before,
  ) {
    if (before == null) {
      batch.set(ref, now);
      return;
    }
    final updates = <Object, Object?>{};
    now.forEach((key, value) {
      if (canonicalJson(value) == canonicalJson(before[key])) return;
      if (key == 'likedBy' || key == 'savedBy' || key == 'viewedBy') {
        final current = {...(value as List<dynamic>? ?? [])};
        final previous = {...(before[key] as List<dynamic>? ?? [])};
        final added = current.difference(previous).toList();
        final removed = previous.difference(current).toList();
        if (added.isNotEmpty && removed.isEmpty) {
          updates[key] = FieldValue.arrayUnion(added);
        } else if (removed.isNotEmpty && added.isEmpty) {
          updates[key] = FieldValue.arrayRemove(removed);
        } else {
          updates[key] = value;
        }
        return;
      }
      if (key == 'comments') {
        final previous = before[key] as List<dynamic>? ?? [];
        final current = value as List<dynamic>? ?? [];
        final previousJson = previous.map(canonicalJson).toList();
        final onlyAppended = current.length > previous.length &&
            [
              for (var i = 0; i < previous.length; i++)
                canonicalJson(current[i]) == previousJson[i],
            ].every((same) => same);
        updates[key] = onlyAppended
            ? FieldValue.arrayUnion(current.sublist(previous.length))
            : value;
        return;
      }
      updates[key] = value;
    });
    if (updates.isNotEmpty) batch.update(ref, updates);
  }

  // ----------------------------------------------------------- current user

  /// Key used to remember who liked/saved something.
  static String userKey(AppAccount? account) => account?.email ?? 'guest';

  static FeedAuthor authorFor(AppAccount account) {
    final handle = account.email
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');
    final title = [
      account.typeLabel,
      if (account.hospital.isNotEmpty) account.hospital,
    ].join(' · ');
    const palette = [
      0xFF4F46E5,
      0xFF7C3AED,
      0xFF0EA5E9,
      0xFF16A34A,
      0xFFEA580C,
      0xFFDB2777,
    ];
    return FeedAuthor(
      handle: handle.isEmpty ? 'user' : handle,
      name: account.fullName.isEmpty ? handle : account.fullName,
      title: title,
      colorValue: palette[account.email.hashCode.abs() % palette.length],
      // Only hired doctors and managers get the verified badge; Students
      // and New Doctors looking for work don't.
      verified: account.practises ||
          account.isGeneralManager ||
          account.isDoctorManager,
    );
  }

  // --------------------------------------------------------------- actions

  Future<void> toggleLike(FeedPost post, String user) async {
    post.likedBy.contains(user)
        ? post.likedBy.remove(user)
        : post.likedBy.add(user);
    await _changed();
  }

  Future<void> like(FeedPost post, String user) async {
    if (post.likedBy.add(user)) await _changed();
  }

  Future<void> toggleSave(FeedPost post, String user) async {
    post.savedBy.contains(user)
        ? post.savedBy.remove(user)
        : post.savedBy.add(user);
    await _changed();
  }

  Future<void> toggleCommentLike(FeedComment comment, String user) async {
    comment.likedBy.contains(user)
        ? comment.likedBy.remove(user)
        : comment.likedBy.add(user);
    await _changed();
  }

  Future<void> addComment(FeedPost post, AppAccount account, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    post.comments.add(FeedComment(
      id: _id(),
      author: authorFor(account),
      text: trimmed,
      createdAt: DateTime.now(),
    ));
    await _changed();
  }

  Future<void> markViewed(FeedPost post, String user) async {
    if (post.viewedBy.add(user)) await _changed();
  }

  /// Turns a title and a few tips into an animated health-tip reel.
  Future<FeedPost> createReel({
    required AppAccount account,
    required String title,
    required List<String> tips,
    required int theme,
    String caption = '',
    String topic = 'General',
  }) async {
    await load();
    final author = authorFor(account);
    final reel = FeedPost(
      id: _id(),
      author: author,
      image: '',
      kind: 'reel',
      theme: theme,
      caption: caption.trim().isEmpty ? title.trim() : caption.trim(),
      topic: topic,
      location: account.hospital,
      createdAt: DateTime.now(),
      slides: reelSlidesFor(title: title, tips: tips, handle: author.handle),
      authorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
    );
    _posts!.insert(0, reel);
    await _changed();
    return reel;
  }

  /// The slides of a user-made reel: a title card, one card per tip and a
  /// closing "Follow" card. Also used for the live preview while composing.
  static List<ReelSlide> reelSlidesFor({
    required String title,
    required List<String> tips,
    required String handle,
  }) {
    final cleanTips = tips
        .map((tip) => tip.trim())
        .where((tip) => tip.isNotEmpty)
        .take(6)
        .toList();
    final heading = title.trim().isEmpty ? 'Your health tip' : title.trim();
    return [
      ReelSlide(
          type: 'title',
          title: heading,
          body: cleanTips.length == 1
              ? '1 quick tip'
              : '${cleanTips.length} quick tips',
          icon: 'sparkle'),
      for (var i = 0; i < cleanTips.length; i++)
        ReelSlide(
            type: 'step',
            title: 'Tip ${i + 1}',
            body: cleanTips[i],
            icon: 'check',
            seconds: 4),
      ReelSlide(
          type: 'outro',
          title: 'Follow @$handle',
          body: 'for more health tips',
          icon: 'heart'),
    ];
  }

  _FollowDoc? _followsOf(String user) {
    for (final doc in _followDocs) {
      if (doc.email == user) return doc;
    }
    return null;
  }

  bool isFollowing(String user, String handle) =>
      _followsOf(user)?.handles.contains(handle) ?? false;

  Future<void> toggleFollow(String user, String handle) async {
    var doc = _followsOf(user);
    if (doc == null) {
      doc = _FollowDoc(user, <String>{});
      _followDocs.add(doc);
    }
    doc.handles.contains(handle)
        ? doc.handles.remove(handle)
        : doc.handles.add(handle);
    await _changed();
  }

  /// Copies the chosen image into the app's data folder and publishes it.
  Future<FeedPost> createPost({
    required AppAccount account,
    required String sourcePath,
    required String caption,
    String topic = 'General',
    String location = '',
  }) async {
    await load();
    final id = _id();
    final image = await MediaService.instance.uploadFile(sourcePath);

    final post = FeedPost(
      id: id,
      author: authorFor(account),
      image: image,
      isAsset: false,
      authorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      caption: caption.trim(),
      topic: topic,
      location: location.trim(),
      createdAt: DateTime.now(),
    );
    _posts!.insert(0, post);
    await _changed();
    return post;
  }

  Future<void> deletePost(FeedPost post) async {
    _postList.removeWhere((item) => item.id == post.id);
    await _changed();
  }

  // ------------------------------------------------------------- formatting

  /// Instagram-style relative time: "now", "5m", "3h", "2d", "4w".
  static String timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }

  static const _months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY',
    'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  /// "3 HOURS AGO" for recent posts, otherwise "OCTOBER 28".
  static String postDate(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'JUST NOW';
    if (diff.inHours < 1) {
      return '${diff.inMinutes} MINUTE${diff.inMinutes == 1 ? '' : 'S'} AGO';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} HOUR${diff.inHours == 1 ? '' : 'S'} AGO';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} DAY${diff.inDays == 1 ? '' : 'S'} AGO';
    }
    return '${_months[time.month - 1]} ${time.day}';
  }

  static String count(int value) {
    if (value < 1000) return '$value';
    if (value < 10000) {
      final text = (value / 1000).toStringAsFixed(1);
      return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}K';
    }
    if (value < 1000000) return '${value ~/ 1000}K';
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }

  /// "1,284" style for the likes line.
  static String grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static final _random = Random();

  static String _id() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';

  // ------------------------------------------------------------ sample data

  static const _official = FeedAuthor(
      handle: 'findoctor.health',
      name: 'Find Doctor Health',
      title: 'Health tips from the Find Doctor team',
      colorValue: 0xFF4F46E5,
      verified: true,
      isDemo: true);
  static const _aina = FeedAuthor(
      handle: 'dr.aina.cardio',
      name: 'Dr. Aina Rahim',
      title: 'Cardiologist · Hospital Pulau Pinang',
      colorValue: 0xFFE11D48,
      verified: true,
      isDemo: true);
  static const _ravi = FeedAuthor(
      handle: 'dr.kumar.peds',
      name: 'Dr. Ravi Kumar',
      title: 'Paediatrician · Hospital Tunku Azizah',
      colorValue: 0xFFEA580C,
      verified: true,
      isDemo: true);
  static const _mei = FeedAuthor(
      handle: 'nutri.mei',
      name: 'Tan Mei Ling',
      title: 'Dietitian · Sunway Medical Centre (Sunway City)',
      colorValue: 0xFFCA8A04,
      verified: true,
      isDemo: true);
  static const _hafiz = FeedAuthor(
      handle: 'dr.hafiz.ed',
      name: 'Dr. Hafiz Osman',
      title: 'Emergency Physician · Hospital Sultanah Aminah',
      colorValue: 0xFFDC2626,
      verified: true,
      isDemo: true);
  static const _sara = FeedAuthor(
      handle: 'mind.with.dr.sara',
      name: 'Dr. Sara Lim',
      title: 'Psychiatrist · Hospital Selayang',
      colorValue: 0xFF7C3AED,
      verified: true,
      isDemo: true);
  static const _daniel = FeedAuthor(
      handle: 'physio.daniel',
      name: 'Daniel Wong',
      title: 'Physiotherapist · KPJ Damansara Specialist Hospital',
      colorValue: 0xFF0EA5E9,
      verified: true,
      isDemo: true);
  static const _nadia = FeedAuthor(
      handle: 'dr.nadia.derm',
      name: 'Dr. Nadia Ismail',
      title: 'Dermatologist · Gleneagles Hospital Kuala Lumpur',
      colorValue: 0xFFDB2777,
      verified: true,
      isDemo: true);
  static const _amir = FeedAuthor(
      handle: 'amir.runs',
      name: 'Amir Zulkifli',
      title: 'User',
      colorValue: 0xFF16A34A,
      isDemo: true);
  static const _farah = FeedAuthor(
      handle: 'farah.mum',
      name: 'Farah Aziz',
      title: 'User',
      colorValue: 0xFF0891B2,
      isDemo: true);
  static const _jason = FeedAuthor(
      handle: 'jason.tan88',
      name: 'Jason Tan',
      title: 'User',
      colorValue: 0xFF64748B,
      isDemo: true);

  static List<FeedPost> _seedPosts() {
    final now = DateTime.now();
    var minutesAgo = 25;
    FeedComment c(FeedAuthor who, String text, int hoursAgo, [int likes = 0]) =>
        FeedComment(
          id: _id(),
          author: who,
          text: text,
          createdAt: now.subtract(Duration(hours: hoursAgo)),
          baseLikes: likes,
        );
    FeedPost p(String file, FeedAuthor who, String caption, String topic,
        int likes, List<FeedComment> comments,
        {bool tall = false, String location = '', String folder = 'explore'}) {
      final post = FeedPost(
        id: 'seed_$file',
        author: who,
        image: folder == 'explore'
            ? 'assets/images/explore/$file.jpg'
            : 'assets/images/$file',
        tall: tall,
        caption: caption,
        topic: topic,
        location: location,
        createdAt: now.subtract(Duration(minutes: minutesAgo)),
        baseLikes: likes,
        comments: comments,
      );
      minutesAgo = (minutesAgo * 1.45).round() + 40;
      return post;
    }

    return [
      p('sleep_tall', _sara,
          'Your brain cleans itself while you sleep. Protect those hours 🌙 #sleep #mentalhealth',
          'Mind', 2310, [
        c(_farah, 'The screens-off rule is so hard with a toddler 😅', 1, 12),
        c(_sara, '@farah.mum start with 20 minutes, it still helps!', 1, 30),
      ], tall: true),
      p('dengue', _official,
          'Dengue cases rise after heavy rain. Ten minutes every Sunday can protect the whole family. #dengue #malaysia',
          'General', 1876, [
        c(_jason, 'Doing this every weekend now 👍', 3, 4),
      ]),
      p('bp_chart', _aina,
          'A week of home readings tells me far more than one number at the clinic. Same time, same arm, sitting quietly for 5 minutes first. #hypertension',
          'Heart', 942, [
        c(_amir, 'Is morning or evening better?', 5, 2),
        c(_aina, '@amir.runs both! Morning before medicine, and evening.', 4, 18),
      ], location: 'Hospital Pulau Pinang'),
      p('hydration', _official,
          'Hot week ahead ☀️ Keep water with you, especially for children and older family members. #heat',
          'General', 1203, [c(_farah, 'Sharing with my parents 💧', 6)]),
      p('healthy_plate', _mei,
          'Suku-suku separuh: a quarter protein, a quarter rice, half vegetables and fruit. No calorie counting needed 🍽️ #nutrition',
          'Nutrition', 1540, [
        c(_jason, 'Nasi lemak version please 😂', 8, 41),
        c(_mei, '@jason.tan88 less rice, more cucumber & egg, sambal on the side 😉', 7, 63),
      ]),
      p('stroke_tall', _hafiz,
          'Learn FAST. You may be the one who saves a life this year. #stroke #emergency',
          'First aid', 3120, [
        c(_farah, 'Saved this. Everyone should know it.', 10, 22),
      ], tall: true, location: 'Hospital Sultanah Aminah'),
      p('api_haze', _hafiz,
          'Haze season reminder: check the API reading every morning before outdoor plans 😷 #haze',
          'General', 860, []),
      p('eye_202020', _official,
          'Long hours on screens? Try the 20-20-20 rule today 👀 #eyecare',
          'General', 734, [c(_jason, 'My eyes needed this', 14, 3)]),
      p('cpr', _hafiz,
          'Compressions matter most. If you are not trained in rescue breaths, hands-only CPR still helps. #firstaid',
          'First aid', 1489, [
        c(_amir, 'Took a CPR class last month because of your posts 🙏', 20, 15),
      ]),
      p('kids_fever', _ravi,
          'Most fevers in children are viral and settle on their own, but these signs mean see a doctor today. #parenting',
          'Kids', 1112, [
        c(_farah, 'Very helpful, thank you doctor!', 22, 9),
      ], location: 'Hospital Tunku Azizah'),
      p('ribbon_tall', _nadia,
          'October is Breast Cancer Awareness Month 🎀 Knowing your normal is the first step. #pinkoctober',
          'General', 2675, [
        c(_farah, 'Booked my mammogram 💗', 26, 37),
      ], tall: true),
      p('heatstroke', _hafiz,
          'Heatstroke can happen fast, especially to outdoor workers and the elderly. Cool first, then call. #heat',
          'First aid', 998, []),
      p('move_more', _daniel,
          'You don\'t need a gym. Brisk walking 30 minutes, 5 days a week gets you there 🚶 #exercise',
          'Rehab', 812, [c(_amir, 'Walking to the LRT counts right? 😄', 30, 6)]),
      p('quote', _ravi, 'Something I tell parents every day. 💙', 'Kids', 1960, []),
      p('handwash', _official,
          'Six steps, twenty seconds. Sing Happy Birthday twice 🎂🧼 #hygiene',
          'General', 645, []),
      p('sunscreen_tall', _nadia,
          'Malaysian sun is strong all year. Sunscreen is the best anti-ageing cream you can buy ☀️ #skincare',
          'Skin', 2204, [
        c(_jason, 'Even indoors near windows?', 40, 5),
        c(_nadia, '@jason.tan88 yes, if you sit by a sunny window most of the day.', 39, 27),
      ], tall: true),
      p('mind_ok', _sara,
          'If you are struggling, please reach out. You do not have to carry it alone 💜 #mentalhealth',
          'Mind', 3388, [c(_farah, '💜💜💜', 48, 11)]),
      p('ward_open', _official,
          'A brighter space for our youngest patients 🧸 #paediatrics',
          'Kids', 1325, []),
      p('ramadan', _aina,
          'Planning ahead keeps fasting safe for people with diabetes. Talk to us early 🌙 #diabetes',
          'Heart', 1067, []),
      p('recovery', _amir,
          '8 months ago I couldn\'t bend my knee. Today: 5 km 🏃‍♂️ Thank you @physio.daniel!',
          'Rehab', 4410, [
        c(_daniel, 'So proud of you Amir!! 🙌', 60, 52),
        c(_farah, 'This is so inspiring', 58, 8),
      ]),
      p('therapy_rehabilitation.png', _daniel,
          'Group rehab session this morning. Progress happens together 💪 #physiotherapy',
          'Rehab', 1178, [], folder: 'images', location: 'KPJ Damansara Specialist Hospital'),
      p('teeth', _official,
          'Two minutes, two times a day 🦷 #dentalhealth',
          'General', 589, []),
    ];
  }

  static List<FeedPost> _seedReels() {
    final now = DateTime.now();
    var minutesAgo = 50;
    FeedComment c(FeedAuthor who, String text, int hoursAgo, [int likes = 0]) =>
        FeedComment(
          id: _id(),
          author: who,
          text: text,
          createdAt: now.subtract(Duration(hours: hoursAgo)),
          baseLikes: likes,
        );
    FeedPost r(String id, FeedAuthor who, String caption, String topic,
        int theme, int likes, int views, List<ReelSlide> slides,
        [List<FeedComment> comments = const []]) {
      final reel = FeedPost(
        id: 'reel_$id',
        author: who,
        image: '',
        kind: 'reel',
        theme: theme,
        caption: caption,
        topic: topic,
        createdAt: now.subtract(Duration(minutes: minutesAgo)),
        baseLikes: likes,
        baseViews: views,
        slides: slides,
        comments: [...comments],
      );
      minutesAgo = (minutesAgo * 1.6).round() + 55;
      return reel;
    }

    return [
      r('box_breathing', _sara,
          'Try this the next time your chest feels tight with worry. 4 in, 4 hold, 4 out, 4 hold 💜 #anxiety #mentalhealth',
          'Mind', 6, 6120, 48200, const [
        ReelSlide(type: 'title', title: 'Feeling anxious?', body: 'Breathe with me for one minute', icon: 'lungs'),
        ReelSlide(type: 'breath', title: 'Box breathing', body: 'Follow the circle', icon: 'lungs', seconds: 16),
        ReelSlide(type: 'check', title: 'Use it when…', body: 'Before an exam\nStuck in traffic\nYou can\'t fall asleep', icon: 'brain', seconds: 4.5),
        ReelSlide(type: 'outro', title: 'Follow @mind.with.dr.sara', body: 'for more calm', icon: 'heart'),
      ], [
        c(_farah, 'Did this before my driving test. It worked!!', 3, 41),
        c(_jason, 'Saving this 🙏', 2, 6),
      ]),
      r('cpr', _hafiz,
          'If an adult collapses and isn\'t breathing normally: call 999 and push hard and fast. You can\'t make it worse. #CPR #firstaid',
          'First aid', 2, 9870, 112400, const [
        ReelSlide(type: 'title', title: 'Someone collapsed?', body: 'Hands-only CPR can save a life', icon: 'warning'),
        ReelSlide(type: 'step', title: 'Step 1', body: 'Check if they respond and breathe normally. Call 999.', icon: 'phone'),
        ReelSlide(type: 'pulse', title: 'Push to this beat', body: '100–120 per minute · centre of the chest · 5–6 cm deep', icon: 'heart', seconds: 8),
        ReelSlide(type: 'step', title: 'Step 3', body: 'Don\'t stop until help or a defibrillator (AED) arrives.', icon: 'clock'),
        ReelSlide(type: 'outro', title: 'Follow @dr.hafiz.ed', body: 'learn first aid in 60 seconds', icon: 'heart'),
      ], [
        c(_amir, 'Everyone needs to see this', 9, 120),
        c(_hafiz, '@amir.runs share it with your family group 🙏', 8, 64),
      ]),
      r('home_bp', _aina,
          'Most "high" readings at home are a technique problem. Here\'s how to do it right 🩺 #bloodpressure',
          'Heart', 1, 3410, 27800, const [
        ReelSlide(type: 'title', title: 'Checking BP at home?', body: '4 steps for an accurate reading', icon: 'bp'),
        ReelSlide(type: 'step', title: 'Step 1', body: 'Sit quietly for 5 minutes. Back supported, feet flat on the floor.', icon: 'clock'),
        ReelSlide(type: 'step', title: 'Step 2', body: 'Cuff on your bare upper arm, at the level of your heart.', icon: 'bp'),
        ReelSlide(type: 'step', title: 'Step 3', body: 'No coffee, smoking or exercise for 30 minutes before.', icon: 'warning'),
        ReelSlide(type: 'step', title: 'Step 4', body: 'Take 2 readings, 1 minute apart. Write both down.', icon: 'check'),
        ReelSlide(type: 'outro', title: 'Follow @dr.aina.cardio', body: 'for heart health tips', icon: 'heart'),
      ], [
        c(_jason, 'I always measured right after kopi 😅', 20, 33),
      ]),
      r('dengue_signs', _ravi,
          'Dengue fever can turn serious when the fever starts going down. Know these warning signs 🦟 #dengue #parenting',
          'Kids', 4, 4580, 39100, const [
        ReelSlide(type: 'title', title: 'Fever after the rainy season?', body: 'Watch for dengue warning signs', icon: 'mosquito'),
        ReelSlide(type: 'check', title: 'Go to hospital now if…', body: 'Severe stomach pain\nVomiting that won\'t stop\nBleeding gums or nose\nVery drowsy or restless', icon: 'hospital', seconds: 6),
        ReelSlide(type: 'step', title: 'At home', body: 'Drink plenty of fluids. Use paracetamol — avoid ibuprofen and aspirin.', icon: 'water'),
        ReelSlide(type: 'outro', title: 'Follow @dr.kumar.peds', body: 'for parenting health tips', icon: 'heart'),
      ], [
        c(_farah, 'Didn\'t know about the ibuprofen part. Thank you doctor', 30, 52),
      ]),
      r('desk_stretch', _daniel,
          'Office workers, this one\'s for you. Do it every 2 hours 🧘 #physio #officelife',
          'Rehab', 3, 2760, 21900, const [
        ReelSlide(type: 'title', title: 'Desk stretches', body: '60 seconds, no equipment', icon: 'stretch'),
        ReelSlide(type: 'step', title: 'Neck tilt', body: 'Ear towards shoulder. Hold 15 seconds each side.', icon: 'stretch'),
        ReelSlide(type: 'step', title: 'Shoulder rolls', body: 'Roll both shoulders backwards 10 times.', icon: 'stretch'),
        ReelSlide(type: 'step', title: 'Seated twist', body: 'Turn your chest to one side. Hold 15 seconds each side.', icon: 'stretch'),
        ReelSlide(type: 'step', title: 'Stand & reach', body: 'Reach up high and take 5 slow breaths.', icon: 'walk'),
        ReelSlide(type: 'outro', title: 'Follow @physio.daniel', body: 'move better every day', icon: 'heart'),
      ]),
      r('food_label', _mei,
          'You don\'t need an app to shop healthier. Flip the pack and check these 🛒 #nutrition',
          'Nutrition', 5, 1980, 16300, const [
        ReelSlide(type: 'title', title: 'Read a food label', body: 'in 30 seconds', icon: 'food'),
        ReelSlide(type: 'step', title: 'Serving size', body: 'Check it first — the numbers are for one serving.', icon: 'food'),
        ReelSlide(type: 'stat', title: '5 g', body: 'sugar per 100 g or less counts as low sugar', icon: 'food'),
        ReelSlide(type: 'step', title: 'Salt', body: 'Over 600 mg sodium per 100 g is high. Compare brands.', icon: 'warning'),
        ReelSlide(type: 'step', title: 'Healthier Choice logo', body: 'A quick shortcut when you are in a hurry.', icon: 'check'),
        ReelSlide(type: 'outro', title: 'Follow @nutri.mei', body: 'for easy nutrition tips', icon: 'heart'),
      ]),
      r('dehydration', _official,
          'Hot day? Check yourself for these signs and keep sipping 💧 #heat #hydration',
          'General', 8, 1540, 12700, const [
        ReelSlide(type: 'title', title: 'Are you dehydrated?', body: '3 signs to check', icon: 'water'),
        ReelSlide(type: 'check', title: 'Watch for', body: 'Dark yellow urine\nHeadache or dizziness\nDry mouth and tiredness', icon: 'water', seconds: 5),
        ReelSlide(type: 'step', title: 'Fix it', body: 'Sip water through the day. Drink more when you sweat.', icon: 'water'),
        ReelSlide(type: 'outro', title: 'Follow @findoctor.health', body: 'for daily health tips', icon: 'heart'),
      ]),
      r('skincare', _nadia,
          'Skincare doesn\'t need 10 steps. Start with these three ✨ #skincare #dermatology',
          'Skin', 7, 3090, 25600, const [
        ReelSlide(type: 'title', title: 'Morning skincare', body: 'only 3 steps', icon: 'skin'),
        ReelSlide(type: 'step', title: '1 · Cleanse', body: 'A gentle, fragrance-free cleanser.', icon: 'water'),
        ReelSlide(type: 'step', title: '2 · Moisturise', body: 'Even oily skin needs a light moisturiser.', icon: 'skin'),
        ReelSlide(type: 'step', title: '3 · Sunscreen', body: 'SPF 30 or higher — the step that matters most.', icon: 'sun'),
        ReelSlide(type: 'outro', title: 'Follow @dr.nadia.derm', body: 'for skin health tips', icon: 'heart'),
      ], [
        c(_farah, 'Finally a simple routine 🙌', 40, 18),
      ]),
    ];
  }
}

/// Who one person follows (Firestore `follows/{email}`).
class _FollowDoc {
  _FollowDoc(this.email, this.handles);
  final String email;
  final Set<String> handles;

  Map<String, dynamic> toJson() => {'handles': handles.toList()};

  factory _FollowDoc.fromJson(String id, Map<String, dynamic> json) =>
      _FollowDoc(id, {...(json['handles'] as List<dynamic>? ?? []).cast<String>()});
}
