import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/fd_palette.dart';
import '../services/account_service.dart';
import '../services/connect_service.dart';
import '../services/post_service.dart';
import 'connect_screens.dart';
import 'explore_tab.dart';
import 'prototype_session.dart';
import 'reels.dart';

/// Story ring for unseen reels (cyan → indigo → pink).
const _ringColors = [Color(0xFF06B6D4), Color(0xFF4F46E5), Color(0xFFDB2777)];

/// Turns "#tags" and "@mentions" in a caption into link-blue text.
List<InlineSpan> captionSpans(String text) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'([#@][\w.]+)');
  var last = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: const TextStyle(color: kLinkBlue),
    ));
    last = match.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

/// Instagram-home-style feed of health posts and reels.
class PostsFeed extends StatelessWidget {
  const PostsFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PostService.instance;
    final account = context.watch<PrototypeSession>().account;
    final user = PostService.userKey(account);
    final me = account == null ? null : PostService.authorFor(account);
    final posts = service.posts;
    final reels = service.reels;
    final photos = service.photoPosts;

    // Health posts, reels and community-group posts, newest first.
    final groupPosts = context.watch<ConnectService>().communityPosts();
    final items = <Object>[...posts, ...groupPosts];
    DateTime dateOf(Object item) => item is FeedPost
        ? item.createdAt
        : (item as (Conversation, ConnectMessage)).$2.createdAt;
    items.sort((a, b) => dateOf(b).compareTo(dateOf(a)));

    // Stories: everyone (except you) who has posted a reel; unseen first.
    final storyAuthors = <FeedAuthor>[];
    final seenHandles = <String>{};
    for (final reel in reels) {
      if (reel.author.handle == me?.handle) continue;
      if (storyAuthors.any((author) => author.handle == reel.author.handle)) {
        continue;
      }
      storyAuthors.add(reel.author);
    }
    for (final author in storyAuthors) {
      final theirs = reels.where((reel) => reel.author.handle == author.handle);
      if (theirs.every((reel) => reel.viewedBy.contains(user))) {
        seenHandles.add(author.handle);
      }
    }
    storyAuthors.sort((a, b) {
      final seenA = seenHandles.contains(a.handle) ? 1 : 0;
      final seenB = seenHandles.contains(b.handle) ? 1 : 0;
      return seenA - seenB;
    });

    void openStory(FeedAuthor author) {
      final index =
          reels.indexWhere((reel) => reel.author.handle == author.handle);
      if (index >= 0) showReelsViewerDialog(context, reels, index);
    }

    void open(FeedPost post) {
      if (post.isReel) {
        showReelsViewerDialog(context, reels, reels.indexOf(post));
      } else {
        showFeedPostViewer(context, photos, photos.indexOf(post));
      }
    }

    final hasMyReels =
        me != null && reels.any((reel) => reel.author.handle == me.handle);

    return LayoutBuilder(builder: (context, constraints) {
      const feedWidth = 630.0;
      const railGap = 64.0;
      const railWidth = 320.0;
      final showRail =
          constraints.maxWidth >= feedWidth + railGap + railWidth + 40;
      final total = showRail
          ? feedWidth + railGap + railWidth
          : math.min(feedWidth, constraints.maxWidth);
      final left = math.max(0.0, (constraints.maxWidth - total) / 2);
      final columnWidth = math.min(feedWidth, constraints.maxWidth);

      Widget inColumn(Widget child, {double maxWidth = 470}) => Padding(
            padding: EdgeInsets.only(left: left),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: columnWidth,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: child,
                  ),
                ),
              ),
            ),
          );

      return Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.only(top: 18, bottom: 40),
            itemCount: items.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return inColumn(
                  _StoriesRow(
                    me: me,
                    hasMyReels: hasMyReels,
                    authors: storyAuthors,
                    seen: seenHandles,
                    onOpen: openStory,
                    onMine: () {
                      if (hasMyReels) {
                        openStory(me!);
                      } else {
                        showCreatePostDialog(context, reel: true);
                      }
                    },
                    onCreate: () => showCreatePostDialog(context, reel: true),
                  ),
                  maxWidth: feedWidth,
                );
              }
              if (index == items.length + 1) {
                return inColumn(const _CaughtUp());
              }
              final item = items[index - 1];
              if (item is (Conversation, ConnectMessage)) {
                return inColumn(
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GroupPostCard(
                      key: ValueKey('group-${item.$2.id}'),
                      conversation: item.$1,
                      message: item.$2,
                    ),
                  ),
                );
              }
              final post = item as FeedPost;
              final story = storyAuthors
                  .any((author) => author.handle == post.author.handle);
              return inColumn(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FeedCard(
                    key: ValueKey(post.id),
                    post: post,
                    hasStory: story,
                    storySeen: seenHandles.contains(post.author.handle),
                    onStory: story ? () => openStory(post.author) : null,
                    onOpen: () => open(post),
                  ),
                ),
              );
            },
          ),
          if (showRail)
            Positioned(
              left: left + feedWidth + railGap,
              top: 30,
              width: railWidth,
              bottom: 0,
              child: const SingleChildScrollView(child: _SuggestionsRail()),
            ),
        ],
      );
    });
  }
}

// ======================================================================
// Stories
// ======================================================================

/// Avatar with Instagram's story ring (coloured = new, grey = seen).
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    required this.author,
    this.size = 36,
    this.ring = false,
    this.seen = false,
    this.onTap,
  });

  final FeedAuthor author;
  final double size;
  final bool ring;
  final bool seen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stroke = size > 50 ? 2.5 : 2.0;
    final avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? stroke : 0),
      decoration: ring
          ? BoxDecoration(
              shape: BoxShape.circle,
              gradient: seen
                  ? null
                  : const LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: _ringColors,
                    ),
              color: seen ? context.fdColor(const Color(0xFFDBDBDB)) : null,
            )
          : null,
      child: Container(
        padding: EdgeInsets.all(ring ? stroke : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.fdColor(Colors.white),
        ),
        child: _InitialsCircle(author: author),
      ),
    );
    if (onTap == null) return avatar;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: avatar),
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({required this.author});
  final FeedAuthor author;

  @override
  Widget build(BuildContext context) {
    final color = Color(author.colorValue);
    return LayoutBuilder(builder: (context, constraints) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.2)!, color],
          ),
        ),
        child: Center(
          child: Text(
            author.initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: constraints.maxWidth * 0.36,
            ),
          ),
        ),
      );
    });
  }
}

class _StoriesRow extends StatefulWidget {
  const _StoriesRow({
    required this.me,
    required this.hasMyReels,
    required this.authors,
    required this.seen,
    required this.onOpen,
    required this.onMine,
    required this.onCreate,
  });

  final FeedAuthor? me;
  final bool hasMyReels;
  final List<FeedAuthor> authors;
  final Set<String> seen;
  final ValueChanged<FeedAuthor> onOpen;
  final VoidCallback onMine;
  final VoidCallback onCreate;

  @override
  State<_StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<_StoriesRow> {
  final _scroll = ScrollController();
  bool _canLeft = false;
  bool _canRight = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void didUpdateWidget(covariant _StoriesRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final left = position.pixels > 4;
    final right = position.pixels < position.maxScrollExtent - 4;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  void _page(int direction) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + direction * 320)
        .clamp(0.0, _scroll.position.maxScrollExtent)
        .toDouble();
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.fdColor(const Color(0xFF262626));
    final muted = context.fdColor(const Color(0xFF737373));
    final me = widget.me;

    Widget story({
      required Widget avatar,
      required String label,
      bool dim = false,
    }) =>
        SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              avatar,
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: dim ? muted : ink)),
            ],
          ),
        );

    Widget arrow(IconData icon, VoidCallback onTap) => Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(icon, size: 20, color: Colors.black87),
            ),
          ),
        );

    final items = <Widget>[
      story(
        label: 'Your story',
        dim: true,
        avatar: SizedBox(
          width: 66,
          height: 66,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (me != null)
                StoryAvatar(
                  author: me,
                  size: 66,
                  ring: widget.hasMyReels,
                  onTap: widget.onMine,
                )
              else
                CircleAvatar(
                  radius: 33,
                  backgroundColor: context.fdColor(const Color(0xFFEFEFEF)),
                  child: Icon(Icons.person_rounded, color: muted, size: 34),
                ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Tooltip(
                  message: 'Create a health tip reel',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onCreate,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: kLinkBlue,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.fdColor(Colors.white), width: 2),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      for (final author in widget.authors)
        story(
          label: author.handle,
          avatar: StoryAvatar(
            author: author,
            size: 66,
            ring: true,
            seen: widget.seen.contains(author.handle),
            onTap: () => widget.onOpen(author),
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        height: 98,
        child: Stack(
          children: [
            ListView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: items,
            ),
            if (_canLeft)
              Positioned(
                left: 6,
                top: 22,
                child: arrow(Icons.chevron_left_rounded, () => _page(-1)),
              ),
            if (_canRight)
              Positioned(
                right: 6,
                top: 22,
                child: arrow(Icons.chevron_right_rounded, () => _page(1)),
              ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Feed card
// ======================================================================

class FeedCard extends StatefulWidget {
  const FeedCard({
    super.key,
    required this.post,
    required this.onOpen,
    this.hasStory = false,
    this.storySeen = false,
    this.onStory,
  });

  final FeedPost post;

  /// Opens the post viewer (photos) or the reels viewer (reels).
  final VoidCallback onOpen;
  final bool hasStory;
  final bool storySeen;
  final VoidCallback? onStory;

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  final _comment = TextEditingController();
  bool _expanded = false;
  bool _heart = false;
  Timer? _heartTimer;

  @override
  void dispose() {
    _heartTimer?.cancel();
    _comment.dispose();
    super.dispose();
  }

  void _doubleTapLike(String user) {
    PostService.instance.like(widget.post, user);
    setState(() => _heart = true);
    _heartTimer?.cancel();
    _heartTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _heart = false);
    });
  }

  Future<void> _send(AppAccount? account) async {
    if (account == null || _comment.text.trim().isEmpty) return;
    await PostService.instance.addComment(widget.post, account, _comment.text);
    _comment.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final account = context.watch<PrototypeSession>().account;
    final user = PostService.userKey(account);
    final me = account == null ? null : PostService.authorFor(account);
    final service = PostService.instance;
    final liked = post.likedBy.contains(user);
    final saved = post.savedBy.contains(user);
    final following = service.isFollowing(user, post.author.handle);
    final isMe = me != null && me.handle == post.author.handle;
    final ink = context.fdColor(const Color(0xFF262626));
    final muted = context.fdColor(const Color(0xFF737373));
    final line = context.fdColor(const Color(0xFFDBDBDB));

    final subtitle = post.isReel
        ? '♫ ${post.author.handle} · Original audio'
        : post.location.isNotEmpty
            ? post.location
            : post.author.title;

    Widget icon(IconData data, String tooltip, VoidCallback onTap,
            {Color? color}) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          icon: Icon(data, size: 26, color: color ?? ink),
        );

    // ----- media
    final Widget media;
    if (post.isReel) {
      media = AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ReelPlayer(reel: post, captionOverlay: false),
            Positioned(
              left: 10,
              bottom: 10,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 2),
                    Text('${PostService.count(post.views)} views',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Open in Reels',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onOpen,
                  icon: const Icon(Icons.open_in_full_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      media = AspectRatio(
        aspectRatio: post.tall ? 4 / 5 : 1,
        child: GestureDetector(
          onDoubleTap: () => _doubleTapLike(user),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: context.fdColor(const Color(0xFFEFEFEF)),
                child:
                    FeedImage(post: post, fit: BoxFit.cover, cacheWidth: 1000),
              ),
              Center(
                child: AnimatedScale(
                  scale: _heart ? 1 : 0.4,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _heart ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.white,
                        size: 100,
                        shadows: [
                          Shadow(blurRadius: 18, color: Colors.black38)
                        ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final longCaption =
        post.caption.length > 110 || post.caption.contains('\n');
    final myComments = me == null
        ? const <FeedComment>[]
        : post.comments
            .where((comment) => comment.author.handle == me.handle)
            .toList()
            .reversed
            .take(2)
            .toList()
            .reversed
            .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                StoryAvatar(
                  author: post.author,
                  size: 38,
                  ring: widget.hasStory,
                  seen: widget.storySeen,
                  onTap: widget.onStory,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(post.author.handle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: ink)),
                        ),
                        if (post.author.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 14, color: kLinkBlue),
                        ],
                        Text('  •  ${PostService.timeAgo(post.createdAt)}',
                            style: TextStyle(fontSize: 14, color: muted)),
                        if (!isMe && !following) ...[
                          Text('  •  ', style: TextStyle(color: muted)),
                          InkWell(
                            onTap: () =>
                                service.toggleFollow(user, post.author.handle),
                            child: const Text('Follow',
                                style: TextStyle(
                                    color: kLinkBlue,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ),
                        ],
                      ]),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: ink)),
                    ],
                  ),
                ),
                if (post.author.isDemo)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.fdColor(const Color(0xFFEFEFEF)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Demo',
                        style: TextStyle(fontSize: 10, color: muted)),
                  ),
                IconButton(
                  tooltip: 'More options',
                  onPressed: () => showPostOptions(context, post),
                  icon: Icon(Icons.more_horiz_rounded, color: ink),
                ),
              ],
            ),
          ),
          // Media
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(color: line, width: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: media,
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(-8, 0),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      liked ? 'Unlike' : 'Like',
                      () => service.toggleLike(post, user),
                      color: liked ? const Color(0xFFFF3040) : null,
                    ),
                    icon(Icons.mode_comment_outlined, 'Comment', widget.onOpen),
                    icon(Icons.send_outlined, 'Share', () async {
                      await Clipboard.setData(ClipboardData(
                          text:
                              'findoctor://${post.isReel ? 'reel' : 'post'}/${post.id}'));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Link copied to clipboard')));
                      }
                    }),
                  ]),
                ),
                const Spacer(),
                Transform.translate(
                  offset: const Offset(8, 0),
                  child: icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    saved ? 'Remove from saved' : 'Save',
                    () => service.toggleSave(post, user),
                  ),
                ),
              ],
            ),
          ),
          Text(
            post.likes == 0
                ? 'Be the first to like this'
                : '${PostService.grouped(post.likes)} like${post.likes == 1 ? '' : 's'}',
            style:
                TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ink),
          ),
          if (post.caption.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${post.author.handle} ',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                ...captionSpans(post.caption),
              ]),
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: ink, height: 1.35),
            ),
            if (longCaption && !_expanded)
              InkWell(
                onTap: () => setState(() => _expanded = true),
                child: Text('more',
                    style: TextStyle(fontSize: 14, color: muted)),
              ),
          ],
          if (post.comments.isNotEmpty) ...[
            const SizedBox(height: 5),
            InkWell(
              onTap: widget.onOpen,
              child: Text(
                post.comments.length == 1
                    ? 'View 1 comment'
                    : 'View all ${post.comments.length} comments',
                style: TextStyle(fontSize: 14, color: muted),
              ),
            ),
          ],
          for (final comment in myComments)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${comment.author.handle} ',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  ...captionSpans(comment.text),
                ]),
                style: TextStyle(fontSize: 14, color: ink, height: 1.35),
              ),
            ),
          // Add a comment
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _comment,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(account),
                  style: TextStyle(fontSize: 14, color: ink),
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    hintStyle: TextStyle(color: muted),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_comment.text.trim().isNotEmpty)
                TextButton(
                  onPressed: () => _send(account),
                  child: const Text('Post',
                      style: TextStyle(
                          color: kLinkBlue, fontWeight: FontWeight.w700)),
                ),
              IconButton(
                tooltip: 'Emoji',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _comment.text = '${_comment.text}🙏';
                  _comment.selection =
                      TextSelection.collapsed(offset: _comment.text.length);
                  setState(() {});
                },
                icon: Icon(Icons.sentiment_satisfied_alt_outlined,
                    size: 16, color: muted),
              ),
            ],
          ),
          Divider(height: 18, color: line),
        ],
      ),
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp();

  @override
  Widget build(BuildContext context) {
    final ink = context.fdColor(const Color(0xFF262626));
    final muted = context.fdColor(const Color(0xFF737373));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: _ringColors),
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.fdColor(Colors.white),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 34, color: Color(0xFF4F46E5)),
            ),
          ),
          const SizedBox(height: 12),
          Text("You're all caught up",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: ink)),
          const SizedBox(height: 4),
          Text("You've seen all the latest health tips.",
              style: TextStyle(fontSize: 14, color: muted)),
        ],
      ),
    );
  }
}

// ======================================================================
// "Suggested for you"
// ======================================================================

class _SuggestionsRail extends StatefulWidget {
  const _SuggestionsRail();

  @override
  State<_SuggestionsRail> createState() => _SuggestionsRailState();
}

class _SuggestionsRailState extends State<_SuggestionsRail> {
  bool _all = false;

  @override
  void initState() {
    super.initState();
    PostService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    PostService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PrototypeSession>();
    final account = session.account;
    final user = PostService.userKey(account);
    final me = account == null ? null : PostService.authorFor(account);
    final service = PostService.instance;
    final ink = context.fdColor(const Color(0xFF262626));
    final muted = context.fdColor(const Color(0xFF737373));

    final suggestions = service.authors
        .where((author) => author.handle != me?.handle)
        .toList()
      // Health professionals first, like "Popular" suggestions.
      ..sort((a, b) => (b.verified ? 1 : 0) - (a.verified ? 1 : 0));
    final shown = _all ? suggestions : suggestions.take(5).toList();

    Widget person(FeedAuthor author, String subtitle, Widget trailing,
            {double size = 44}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              FeedAvatar(author: author, size: size),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(author.handle,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: ink)),
                      ),
                      if (author.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 13, color: kLinkBlue),
                      ],
                    ]),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (me != null)
          person(
            me,
            me.name,
            Text(session.accountTypeLabel,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kLinkBlue)),
            size: 48,
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text('Suggested for you',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: muted)),
          ),
          if (suggestions.length > 5)
            InkWell(
              onTap: () => setState(() => _all = !_all),
              child: Text(_all ? 'Show less' : 'See all',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
            ),
        ]),
        const SizedBox(height: 4),
        for (final author in shown)
          person(
            author,
            author.title.isEmpty ? 'Suggested for you' : author.title,
            InkWell(
              onTap: () => service.toggleFollow(user, author.handle),
              child: Text(
                service.isFollowing(user, author.handle)
                    ? 'Following'
                    : 'Follow',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: service.isFollowing(user, author.handle)
                      ? ink
                      : kLinkBlue,
                ),
              ),
            ),
            size: 40,
          ),
        const CommunitySuggestions(),
        const SizedBox(height: 24),
        Text(
          'Health tips here are general information, not a diagnosis. '
          'For an emergency in Malaysia call 999.',
          style: TextStyle(fontSize: 11.5, color: muted, height: 1.4),
        ),
        const SizedBox(height: 10),
        Text('© 2026 FIND DOCTOR',
            style: TextStyle(
                fontSize: 11.5, color: muted, letterSpacing: 0.4)),
        const SizedBox(height: 24),
      ],
    );
  }
}
