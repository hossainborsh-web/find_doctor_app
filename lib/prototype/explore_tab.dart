import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/domain/entities/user_role.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/fd_palette.dart';
import '../core/widgets/fd_image.dart';
import '../services/account_service.dart';
import '../services/image_picker_service.dart';
import '../services/post_service.dart';
import 'explore_feed.dart';
import 'prototype_session.dart';
import 'reels.dart';

// Instagram-style link blue used for "Follow", "Post" and "Share".
const kLinkBlue = Color(0xFF0095F6);
const double _gap = 4;

enum ExploreSection { posts, reels, explore }

/// Health content laid out like Instagram on desktop:
/// * Posts — a home feed of post and reel cards with stories on top and
///   "Suggested for you" on the right.
/// * Reels — a vertical player of animated health-tip reels.
/// * Explore — a mosaic grid of everything, reels in the tall slots.
/// Every signed-in user can create a photo post or a health-tip reel.
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key, required this.role});
  final UserRole role;

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final _search = TextEditingController();
  String _query = '';
  ExploreSection _section = ExploreSection.posts;

  @override
  void initState() {
    super.initState();
    PostService.instance.addListener(_onFeedChanged);
    PostService.instance.load();
  }

  @override
  void dispose() {
    PostService.instance.removeListener(_onFeedChanged);
    _search.dispose();
    super.dispose();
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
  }

  List<FeedPost> get _filtered {
    final query = _query.trim().toLowerCase();
    final posts = PostService.instance.posts;
    if (query.isEmpty) return posts;
    return posts.where((post) {
      return post.caption.toLowerCase().contains(query) ||
          post.author.handle.contains(query) ||
          post.author.name.toLowerCase().contains(query) ||
          post.topic.toLowerCase().contains(query) ||
          post.location.toLowerCase().contains(query) ||
          post.slides.any((slide) =>
              slide.title.toLowerCase().contains(query) ||
              slide.body.toLowerCase().contains(query));
    }).toList();
  }

  /// Groups posts into blocks of five. Reels (and portrait photos) fill the
  /// tall slot, like Instagram's Explore page.
  static List<List<FeedPost>> _blocks(List<FeedPost> posts) {
    final reels = posts.where((post) => post.isReel).toList();
    final tallPhotos = posts.where((post) => !post.isReel && post.tall).toList();
    final square = posts.where((post) => !post.isReel && !post.tall).toList();
    final tall = <FeedPost>[];
    while (reels.isNotEmpty || tallPhotos.isNotEmpty) {
      for (var i = 0; i < 2 && reels.isNotEmpty; i++) {
        tall.add(reels.removeAt(0));
      }
      if (tallPhotos.isNotEmpty) tall.add(tallPhotos.removeAt(0));
    }
    final blocks = <List<FeedPost>>[];
    while (tall.length + square.length >= 5) {
      final first = tall.isNotEmpty ? tall.removeAt(0) : square.removeAt(0);
      final rest = <FeedPost>[];
      while (rest.length < 4) {
        rest.add(square.isNotEmpty ? square.removeAt(0) : tall.removeAt(0));
      }
      blocks.add([first, ...rest]);
    }
    final leftover = [...square, ...tall];
    if (leftover.isNotEmpty) blocks.add(leftover);
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final service = PostService.instance;
    final background = context.fdColor(Colors.white);
    final loaded = service.isLoaded;

    late final Widget body;
    if (!loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      switch (_section) {
        case ExploreSection.posts:
          body = PostsFeed(key: const ValueKey('posts'));
        case ExploreSection.reels:
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ReelsViewer(
                key: const ValueKey('reels'), reels: service.reels),
          );
        case ExploreSection.explore:
          body = _buildGrid(context);
      }
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SectionBar(
              section: _section,
              onChanged: (section) => setState(() => _section = section),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final blocks = _blocks(_filtered);
    final ordered = [for (final block in blocks) ...block];
    final ink = context.fdColor(AppColors.neutralBlack);

    void open(FeedPost post) {
      if (post.isReel) {
        final reels = ordered.where((item) => item.isReel).toList();
        showReelsViewerDialog(context, reels, reels.indexOf(post));
      } else {
        final photos = ordered.where((item) => !item.isReel).toList();
        showFeedPostViewer(context, photos, photos.indexOf(post));
      }
    }

    return CustomScrollView(
      key: const ValueKey('explore'),
      slivers: [
        SliverToBoxAdapter(
          child: _Centered(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              child: _SearchField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
        ),
        if (ordered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                _query.isEmpty
                    ? 'No posts yet. Be the first to share one!'
                    : 'No results for "$_query"',
                style: TextStyle(color: ink, fontSize: 15),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _Centered(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: _MosaicBlock(
                    posts: blocks[index],
                    tallOnRight: index.isEven,
                    onOpen: open,
                  ),
                ),
              ),
              childCount: blocks.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

/// POSTS · REELS · EXPLORE tabs (Instagram profile-tab style) and Create.
class _SectionBar extends StatelessWidget {
  const _SectionBar({required this.section, required this.onChanged});
  final ExploreSection section;
  final ValueChanged<ExploreSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final ink = context.fdColor(const Color(0xFF262626));
    final muted = context.fdColor(const Color(0xFF737373));
    final line = context.fdColor(const Color(0xFFDBDBDB));
    const tabs = ExploreSection.values;

    Widget tab(ExploreSection item) {
      final selected = item == section;
      final color = selected ? ink : muted;
      final IconData iconData;
      final String text;
      switch (item) {
        case ExploreSection.posts:
          iconData = Icons.view_agenda_outlined;
          text = 'POSTS';
        case ExploreSection.reels:
          iconData = Icons.movie_creation_outlined;
          text = 'REELS';
        case ExploreSection.explore:
          iconData = Icons.explore_outlined;
          text = 'EXPLORE';
      }
      return InkWell(
        onTap: () => onChanged(item),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? ink : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(iconData, size: 18, color: color),
            const SizedBox(width: 7),
            Text(text,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                )),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final roomy = constraints.maxWidth >= 640;
        final create = roomy
            ? FilledButton.icon(
                onPressed: () => showCreatePostDialog(context),
                icon: const Icon(Icons.add_box_outlined, size: 19),
                label: const Text('Create'),
                style: FilledButton.styleFrom(
                  backgroundColor: kLinkBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              )
            : IconButton(
                tooltip: 'Create',
                onPressed: () => showCreatePostDialog(context),
                icon: Icon(Icons.add_box_outlined, color: ink),
              );
        return Row(
          children: [
            SizedBox(width: roomy ? 130 : 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minWidth: (constraints.maxWidth - (roomy ? 260 : 56))
                          .clamp(0.0, double.infinity)
                          .toDouble()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final item in tabs) ...[
                        tab(item),
                        if (item != tabs.last) const SizedBox(width: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: roomy ? 130 : 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: roomy ? 18 : 4),
                  child: create,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 975),
          child: child,
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = context.fdColor(AppColors.darkGrey);
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: context.fdColor(AppColors.neutralBlack)),
        decoration: InputDecoration(
          hintText: 'Search posts, people, hospitals',
          prefixIcon: Icon(Icons.search_rounded, color: muted),
          filled: true,
          fillColor: context.fdColor(const Color(0xFFEFEFEF)),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _MosaicBlock extends StatelessWidget {
  const _MosaicBlock({
    required this.posts,
    required this.tallOnRight,
    required this.onOpen,
  });

  final List<FeedPost> posts;
  final bool tallOnRight;
  final ValueChanged<FeedPost> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cell = (constraints.maxWidth - _gap * 2) / 3;
      Widget tile(FeedPost post, double height) => SizedBox(
            width: cell,
            height: height,
            child: _GridTile(post: post, onTap: () => onOpen(post)),
          );

      if (posts.length < 5) {
        final rows = <Widget>[];
        for (var i = 0; i < posts.length; i += 3) {
          final row = posts.sublist(i, (i + 3).clamp(0, posts.length));
          rows.add(Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _gap),
            child: Row(children: [
              for (var j = 0; j < row.length; j++) ...[
                if (j > 0) const SizedBox(width: _gap),
                tile(row[j], cell),
              ],
            ]),
          ));
        }
        return Column(children: rows);
      }

      final tall = tile(posts[0], cell * 2 + _gap);
      final grid = SizedBox(
        width: cell * 2 + _gap,
        child: Column(children: [
          Row(children: [
            tile(posts[1], cell),
            const SizedBox(width: _gap),
            tile(posts[2], cell),
          ]),
          const SizedBox(height: _gap),
          Row(children: [
            tile(posts[3], cell),
            const SizedBox(width: _gap),
            tile(posts[4], cell),
          ]),
        ]),
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tallOnRight
            ? [grid, const SizedBox(width: _gap), tall]
            : [tall, const SizedBox(width: _gap), grid],
      );
    });
  }
}

/// Grid tile with Instagram's hover overlay (likes and comments counts).
class _GridTile extends StatefulWidget {
  const _GridTile({required this.post, required this.onTap});
  final FeedPost post;
  final VoidCallback onTap;

  @override
  State<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends State<_GridTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    const stat = TextStyle(
        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (post.isReel)
              ReelCover(reel: post)
            else
              ColoredBox(
                color: const Color(0xFFEFEFEF),
                child:
                    FeedImage(post: post, fit: BoxFit.cover, cacheWidth: 700),
              ),
            if (post.tall && !post.isReel)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.collections_rounded,
                    color: Colors.white,
                    size: 20,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black45)]),
              ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hover ? 1 : 0,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.32),
                child: Center(
                  child: Wrap(
                    spacing: 26,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.favorite_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 6),
                        Text(PostService.count(post.likes), style: stat),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.mode_comment_rounded,
                            color: Colors.white, size: 21),
                        const SizedBox(width: 6),
                        Text(PostService.count(post.comments.length),
                            style: stat),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a post's image from the app assets or from a file on this PC.
class FeedImage extends StatelessWidget {
  const FeedImage({
    super.key,
    required this.post,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });

  final FeedPost post;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    Widget broken(BuildContext _, Object __, StackTrace? ___) => const Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.black26, size: 40),
        );
    return FdImage(post.image,
        isAsset: post.isAsset,
        fit: fit,
        cacheWidth: cacheWidth,
        placeholder: broken(context, '', null));
  }
}

class FeedAvatar extends StatelessWidget {
  const FeedAvatar({super.key, required this.author, this.size = 32});
  final FeedAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(author.colorValue);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.45)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.fdColor(Colors.white),
        ),
        padding: const EdgeInsets.all(1.5),
        child: CircleAvatar(
          backgroundColor: color,
          child: Text(
            author.initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.34,
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// "..." options for a post or reel
// ======================================================================

/// Instagram's options sheet: Delete (your own) or Report, Copy caption.
Future<void> showPostOptions(
  BuildContext context,
  FeedPost post, {
  VoidCallback? onDeleted,
}) async {
  final account = context.read<PrototypeSession>().account;
  final mine = account != null &&
      PostService.authorFor(account).handle == post.author.handle &&
      !post.isSample;
  final noun = post.isReel ? 'reel' : 'post';
  final following = PostService.instance
      .isFollowing(PostService.userKey(account), post.author.handle);
  final messenger = ScaffoldMessenger.maybeOf(context);

  Widget option(BuildContext dialogContext, String value, String label,
          {bool danger = false}) =>
      InkWell(
        onTap: () => Navigator.pop(dialogContext, value),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: danger ? FontWeight.w700 : FontWeight.w400,
                color: danger ? const Color(0xFFED4956) : null,
              )),
        ),
      );

  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine)
              option(dialogContext, 'delete', 'Delete', danger: true)
            else
              option(dialogContext, 'report', 'Report', danger: true),
            const Divider(height: 1),
            if (!mine && following) ...[
              option(dialogContext, 'unfollow', 'Unfollow', danger: true),
              const Divider(height: 1),
            ],
            option(dialogContext, 'copy', 'Copy caption'),
            const Divider(height: 1),
            option(dialogContext, 'link', 'Copy link'),
            const Divider(height: 1),
            option(dialogContext, 'cancel', 'Cancel'),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'delete':
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 26),
              Text('Delete $noun?',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Are you sure you want to delete this $noun?',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF737373))),
              const SizedBox(height: 22),
              const Divider(height: 1),
              InkWell(
                onTap: () => Navigator.pop(dialogContext, true),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: const Text('Delete',
                      style: TextStyle(
                          color: Color(0xFFED4956),
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const Divider(height: 1),
              InkWell(
                onTap: () => Navigator.pop(dialogContext, false),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  child: const Text('Cancel'),
                ),
              ),
            ]),
          ),
        ),
      );
      if (confirmed != true) return;
      await PostService.instance.deletePost(post);
      onDeleted?.call();
      messenger?.showSnackBar(SnackBar(
          content: Text('${noun[0].toUpperCase()}${noun.substring(1)} deleted')));
    case 'report':
      messenger?.showSnackBar(
          SnackBar(content: Text('Thanks — we\'ll review this $noun.')));
    case 'unfollow':
      await PostService.instance
          .toggleFollow(PostService.userKey(account), post.author.handle);
      messenger?.showSnackBar(
          SnackBar(content: Text('Unfollowed ${post.author.handle}')));
    case 'copy':
      await Clipboard.setData(ClipboardData(text: post.caption));
      messenger?.showSnackBar(const SnackBar(content: Text('Caption copied')));
    case 'link':
      await Clipboard.setData(
          ClipboardData(text: 'findoctor://$noun/${post.id}'));
      messenger
          ?.showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
  }
}

// ======================================================================
// Post viewer (image left, details right) — like Instagram's post modal
// ======================================================================

Future<void> showFeedPostViewer(
    BuildContext context, List<FeedPost> posts, int index) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, __, ___) => _PostViewer(posts: posts, initialIndex: index),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.98, end: 1.0).animate(animation),
        child: child,
      ),
    ),
  );
}

class _PostViewer extends StatefulWidget {
  const _PostViewer({required this.posts, required this.initialIndex});
  final List<FeedPost> posts;
  final int initialIndex;

  @override
  State<_PostViewer> createState() => _PostViewerState();
}

class _PostViewerState extends State<_PostViewer> {
  late int _index = widget.initialIndex;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    PostService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    PostService.instance.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.posts.length) return;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.posts[_index];
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 820;

    Widget arrow(IconData icon, VoidCallback onTap) => Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, size: 22, color: Colors.black87),
            ),
          ),
        );

    final content = wide
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (size.width - 160).clamp(600.0, 1240.0).toDouble(),
              maxHeight: (size.height - 80).clamp(420.0, 900.0).toDouble(),
            ),
            child: AspectRatio(
              aspectRatio: 1.62,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _ViewerImage(post: post)),
                  SizedBox(
                    width: 420,
                    child: _PostPanel(
                      key: ValueKey(post.id),
                      post: post,
                      onDeleted: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          )
        : ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: size.width - 24, maxHeight: size.height - 60),
            child: Column(
              children: [
                AspectRatio(aspectRatio: 1, child: _ViewerImage(post: post)),
                Expanded(
                  child: _PostPanel(
                    key: ValueKey(post.id),
                    post: post,
                    onDeleted: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _go(1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _go(-1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: content,
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 14,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 30),
            ),
          ),
          if (_index > 0)
            Positioned(
              left: 18,
              top: 0,
              bottom: 0,
              child: Center(
                  child: arrow(Icons.chevron_left_rounded, () => _go(-1))),
            ),
          if (_index < widget.posts.length - 1)
            Positioned(
              right: 18,
              top: 0,
              bottom: 0,
              child: Center(
                  child: arrow(Icons.chevron_right_rounded, () => _go(1))),
            ),
        ],
      ),
    );
  }
}

/// Black image area. Double-click to like, with Instagram's big-heart pop.
class _ViewerImage extends StatefulWidget {
  const _ViewerImage({required this.post});
  final FeedPost post;

  @override
  State<_ViewerImage> createState() => _ViewerImageState();
}

class _ViewerImageState extends State<_ViewerImage> {
  bool _showHeart = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _doubleTapLike() {
    final user = PostService.userKey(context.read<PrototypeSession>().account);
    PostService.instance.like(widget.post, user);
    setState(() => _showHeart = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FeedImage(post: widget.post, fit: BoxFit.contain),
            Center(
              child: AnimatedScale(
                scale: _showHeart ? 1 : 0.4,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _showHeart ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white,
                      size: 110,
                      shadows: [Shadow(blurRadius: 18, color: Colors.black38)]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostPanel extends StatefulWidget {
  const _PostPanel({super.key, required this.post, required this.onDeleted});
  final FeedPost post;
  final VoidCallback onDeleted;

  @override
  State<_PostPanel> createState() => _PostPanelState();
}

class _PostPanelState extends State<_PostPanel> {
  final _comment = TextEditingController();
  final _commentFocus = FocusNode();

  @override
  void dispose() {
    _comment.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _sendComment(AppAccount? account) async {
    if (account == null || _comment.text.trim().isEmpty) return;
    await PostService.instance.addComment(widget.post, account, _comment.text);
    _comment.clear();
    setState(() {});
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final account = context.watch<PrototypeSession>().account;
    final user = PostService.userKey(account);
    final liked = post.likedBy.contains(user);
    final saved = post.savedBy.contains(user);
    final service = PostService.instance;
    final following = service.isFollowing(user, post.author.handle);
    final isMe = account != null &&
        PostService.authorFor(account).handle == post.author.handle;
    final ink = context.fdColor(const Color(0xFF262626));
    final muted = context.fdColor(const Color(0xFF737373));
    final divider = context.fdColor(const Color(0xFFEFEFEF));

    Widget handle(FeedAuthor author) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(author.handle,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: ink)),
            if (author.verified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded, size: 14, color: kLinkBlue),
            ],
          ],
        );

    Widget commentRow({
      required FeedAuthor author,
      required String text,
      required DateTime time,
      FeedComment? comment,
    }) {
      final commentLiked = comment?.likedBy.contains(user) ?? false;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeedAvatar(author: author, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${author.handle} ',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (author.verified)
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.verified_rounded,
                                size: 13, color: kLinkBlue),
                          ),
                        ),
                      TextSpan(text: text),
                    ]),
                    style: TextStyle(fontSize: 14, color: ink, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(PostService.timeAgo(time),
                        style: TextStyle(fontSize: 12, color: muted)),
                    if (comment != null && comment.likes > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                          '${comment.likes} like${comment.likes == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              fontWeight: FontWeight.w600)),
                    ],
                    if (comment != null) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          _comment.text = '@${author.handle} ';
                          _comment.selection = TextSelection.collapsed(
                              offset: _comment.text.length);
                          _commentFocus.requestFocus();
                        },
                        child: Text('Reply',
                            style: TextStyle(
                                fontSize: 12,
                                color: muted,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            if (comment != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 14,
                onPressed: () => service.toggleCommentLike(comment, user),
                icon: Icon(
                  commentLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: commentLiked ? const Color(0xFFFF3040) : muted,
                ),
              ),
          ],
        ),
      );
    }

    return Material(
      color: context.fdColor(Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
            child: Row(
              children: [
                FeedAvatar(author: post.author, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: handle(post.author)),
                          if (!isMe) ...[
                            Text('  •  ', style: TextStyle(color: ink)),
                            InkWell(
                              onTap: () =>
                                  service.toggleFollow(user, post.author.handle),
                              child: Text(
                                following ? 'Following' : 'Follow',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: following ? ink : kLinkBlue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (post.location.isNotEmpty || post.author.title.isNotEmpty)
                        Text(
                          post.location.isNotEmpty
                              ? post.location
                              : post.author.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: ink),
                        ),
                    ],
                  ),
                ),
                if (post.author.isDemo)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: divider,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Demo',
                        style: TextStyle(fontSize: 10, color: muted)),
                  ),
                IconButton(
                  tooltip: 'More options',
                  onPressed: () =>
                      showPostOptions(context, post, onDeleted: widget.onDeleted),
                  icon: Icon(Icons.more_horiz_rounded, color: ink),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: divider),
          // Caption + comments
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              children: [
                if (post.caption.isNotEmpty)
                  commentRow(
                      author: post.author,
                      text: post.caption,
                      time: post.createdAt),
                for (final comment in post.comments)
                  commentRow(
                    author: comment.author,
                    text: comment.text,
                    time: comment.createdAt,
                    comment: comment,
                  ),
                if (post.caption.isEmpty && post.comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(children: [
                      Text('No comments yet.',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: ink)),
                      const SizedBox(height: 6),
                      Text('Start the conversation.',
                          style: TextStyle(fontSize: 14, color: muted)),
                    ]),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: divider),
          // Action bar: like, comment, share ... save
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: liked ? 'Unlike' : 'Like',
                  onPressed: () => service.toggleLike(post, user),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(liked),
                      size: 27,
                      color: liked ? const Color(0xFFFF3040) : ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Comment',
                  onPressed: () => _commentFocus.requestFocus(),
                  icon: Icon(Icons.mode_comment_outlined, size: 25, color: ink),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(
                        text: 'findoctor://post/${post.id}'));
                    _toast('Link copied to clipboard');
                  },
                  icon: Icon(Icons.send_outlined, size: 25, color: ink),
                ),
                const Spacer(),
                IconButton(
                  tooltip: saved ? 'Remove from saved' : 'Save',
                  onPressed: () => service.toggleSave(post, user),
                  icon: Icon(
                    saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 27,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              post.likes == 0
                  ? 'Be the first to like this'
                  : '${PostService.grouped(post.likes)} like${post.likes == 1 ? '' : 's'}',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(PostService.postDate(post.createdAt),
                style: TextStyle(
                    fontSize: 10.5, letterSpacing: 0.3, color: muted)),
          ),
          Divider(height: 1, color: divider),
          // Add a comment
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Emoji',
                  onPressed: () {
                    _comment.text = '${_comment.text}😊';
                    _comment.selection =
                        TextSelection.collapsed(offset: _comment.text.length);
                    setState(() {});
                  },
                  icon: Icon(Icons.sentiment_satisfied_alt_outlined,
                      color: ink, size: 26),
                ),
                Expanded(
                  child: TextField(
                    controller: _comment,
                    focusNode: _commentFocus,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _sendComment(account),
                    style: TextStyle(fontSize: 14, color: ink),
                    decoration: InputDecoration(
                      hintText: 'Add a comment…',
                      hintStyle: TextStyle(color: muted),
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _comment.text.trim().isEmpty
                      ? null
                      : () => _sendComment(account),
                  child: Text(
                    'Post',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _comment.text.trim().isEmpty
                          ? kLinkBlue.withValues(alpha: 0.35)
                          : kLinkBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Create new post — like Instagram's "Create new post" window
// ======================================================================

/// Opens "Create new post". With [reel] it starts on the health-tip reel
/// composer.
Future<void> showCreatePostDialog(BuildContext context, {bool reel = false}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => _CreatePostDialog(startWithReel: reel),
  );
}

enum _CreateStep { pick, compose, reel, done }

class _CreatePostDialog extends StatefulWidget {
  const _CreatePostDialog({this.startWithReel = false});
  final bool startWithReel;

  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  late _CreateStep _step =
      widget.startWithReel ? _CreateStep.reel : _CreateStep.pick;
  String? _path;
  bool _picking = false;
  bool _sharing = false;
  bool _madeReel = false;
  String? _error;
  String _topic = PostService.topics.first;
  final _caption = TextEditingController();
  final _location = TextEditingController();

  // Health-tip reel composer.
  final _reelTitle = TextEditingController();
  final _reelCaption = TextEditingController();
  final _tips = [TextEditingController(), TextEditingController()];
  int _theme = 0;

  @override
  void initState() {
    super.initState();
    final account = context.read<PrototypeSession>().account;
    _location.text = account?.hospital ?? '';
  }

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    _reelTitle.dispose();
    _reelCaption.dispose();
    for (final tip in _tips) {
      tip.dispose();
    }
    super.dispose();
  }

  FeedPost _draftReel(AppAccount? account) {
    final author = account == null
        ? const FeedAuthor(handle: 'you', name: 'You')
        : PostService.authorFor(account);
    return FeedPost(
      id: 'draft_reel',
      author: author,
      image: '',
      kind: 'reel',
      theme: _theme,
      caption: '',
      createdAt: DateTime.now(),
      slides: PostService.reelSlidesFor(
        title: _reelTitle.text,
        tips: [for (final tip in _tips) tip.text],
        handle: author.handle,
      ),
    );
  }

  Future<void> _shareReel() async {
    final account = context.read<PrototypeSession>().account;
    if (account == null) return;
    final tips = [
      for (final tip in _tips)
        if (tip.text.trim().isNotEmpty) tip.text
    ];
    if (_reelTitle.text.trim().isEmpty || tips.isEmpty) {
      setState(() => _error = 'Add a title and at least one tip.');
      return;
    }
    setState(() {
      _sharing = true;
      _error = null;
    });
    await PostService.instance.createReel(
      account: account,
      title: _reelTitle.text,
      tips: tips,
      theme: _theme,
      caption: _reelCaption.text,
      topic: _topic,
    );
    if (!mounted) return;
    setState(() {
      _sharing = false;
      _madeReel = true;
      _step = _CreateStep.done;
    });
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    final path = await pickImageFromComputer(title: 'Choose a photo to share');
    if (!mounted) return;
    setState(() {
      _picking = false;
      if (path != null) {
        _path = path;
        _step = _CreateStep.compose;
      } else if (kIsWeb) {
        _error = 'Uploading photos works in the Windows and Android apps.';
      }
    });
  }

  Future<void> _share() async {
    final account = context.read<PrototypeSession>().account;
    final path = _path;
    if (account == null || path == null) return;
    setState(() => _sharing = true);
    try {
      await PostService.instance.createPost(
        account: account,
        sourcePath: path,
        caption: _caption.text,
        topic: _topic,
        location: _location.text,
      );
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _step = _CreateStep.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _error = 'Could not share this photo. Try another one.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;
    final ink = context.fdColor(const Color(0xFF262626));
    final divider = context.fdColor(const Color(0xFFDBDBDB));
    final square = (size.height - 140).clamp(320.0, 620.0).toDouble();
    final reelPreviewWidth = square * 9 / 16;
    final width = switch (_step) {
      _CreateStep.compose when wide => square + 340,
      _CreateStep.reel when size.width >= 760 => reelPreviewWidth + 400,
      _CreateStep.reel => (size.width - 40).clamp(320.0, 460.0).toDouble(),
      _ => square,
    };

    Widget header({Widget? leading, Widget? trailing, required String title}) =>
        SizedBox(
          height: 46,
          child: Row(
            children: [
              SizedBox(width: 56, child: leading),
              Expanded(
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16, color: ink)),
              ),
              SizedBox(width: 72, child: trailing),
            ],
          ),
        );

    late final Widget body;
    switch (_step) {
      case _CreateStep.pick:
        body = Column(
          children: [
            header(title: 'Create new post'),
            Divider(height: 1, color: divider),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 96, color: ink),
                    const SizedBox(height: 14),
                    Text('Share a health photo or tip',
                        style: TextStyle(fontSize: 20, color: ink)),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _picking ? null : _pick,
                      style: FilledButton.styleFrom(
                        backgroundColor: kLinkBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                      child: Text(_picking ? 'Opening…' : 'Select from computer'),
                    ),
                    const SizedBox(height: 18),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 60, child: Divider(color: divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context
                                    .fdColor(const Color(0xFF737373)))),
                      ),
                      SizedBox(width: 60, child: Divider(color: divider)),
                    ]),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _error = null;
                        _step = _CreateStep.reel;
                      }),
                      icon: const Icon(Icons.movie_creation_outlined, size: 20),
                      label: const Text('Create a health tip reel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: BorderSide(color: divider),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.errorRed)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      case _CreateStep.compose:
        final account = context.watch<PrototypeSession>().account;
        final author = account == null ? null : PostService.authorFor(account);
        final preview = ColoredBox(
          color: Colors.black,
          child: Image.file(File(_path!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 48))),
        );
        final details = ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            if (author != null)
              Row(children: [
                FeedAvatar(author: author, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(author.handle,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14, color: ink)),
                ),
              ]),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              maxLines: 7,
              minLines: 5,
              maxLength: 2200,
              style: TextStyle(fontSize: 15, color: ink),
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Divider(color: divider),
            TextField(
              controller: _location,
              style: TextStyle(fontSize: 14, color: ink),
              decoration: InputDecoration(
                hintText: 'Add location',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                suffixIcon: Icon(Icons.location_on_outlined, color: ink),
              ),
            ),
            Divider(color: divider),
            const SizedBox(height: 6),
            Text('Topic',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, color: ink)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final topic in PostService.topics)
                  ChoiceChip(
                    label: Text(topic),
                    selected: topic == _topic,
                    showCheckmark: false,
                    selectedColor: kLinkBlue,
                    labelStyle: TextStyle(
                        color: topic == _topic ? Colors.white : ink,
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _topic = topic),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
            ],
          ],
        );
        body = Column(
          children: [
            header(
              title: 'Create new post',
              leading: IconButton(
                tooltip: 'Back',
                onPressed: _sharing
                    ? null
                    : () => setState(() {
                          _step = _CreateStep.pick;
                          _path = null;
                        }),
                icon: Icon(Icons.arrow_back_rounded, color: ink),
              ),
              trailing: TextButton(
                onPressed: _sharing ? null : _share,
                child: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Share',
                        style: TextStyle(
                            color: kLinkBlue, fontWeight: FontWeight.w700)),
              ),
            ),
            Divider(height: 1, color: divider),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: square, child: preview),
                        VerticalDivider(width: 1, color: divider),
                        Expanded(child: details),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: square * 0.55, child: preview),
                        Expanded(child: details),
                      ],
                    ),
            ),
          ],
        );
      case _CreateStep.reel:
        final account = context.watch<PrototypeSession>().account;
        final author = account == null ? null : PostService.authorFor(account);
        final muted = context.fdColor(const Color(0xFF737373));
        InputDecoration plain(String hint, {String? counter}) =>
            InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: muted),
              filled: true,
              fillColor: context.fdColor(const Color(0xFFFAFAFA)),
              counterText: counter,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kLinkBlue)),
            );
        Widget label(String text) => Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
              child: Text(text,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: ink)),
            );
        final form = ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            if (author != null)
              Row(children: [
                FeedAvatar(author: author, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(author.handle,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14, color: ink)),
                ),
              ]),
            label('Title'),
            TextField(
              controller: _reelTitle,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 14, color: ink),
              decoration: plain('e.g. Beat the heat', counter: ''),
            ),
            label('Tips (one per slide)'),
            for (var i = 0; i < _tips.length; i++)
              Padding(
                key: ObjectKey(_tips[i]),
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _tips[i],
                  maxLength: 120,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 14, color: ink),
                  decoration: plain('Tip ${i + 1}', counter: '').copyWith(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor:
                            reelThemes[_theme % reelThemes.length].first,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                    suffixIcon: _tips.length > 1
                        ? IconButton(
                            tooltip: 'Remove tip',
                            onPressed: () {
                              final removed = _tips[i];
                              setState(() => _tips.removeAt(i));
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => removed.dispose());
                            },
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: muted),
                          )
                        : null,
                  ),
                ),
              ),
            if (_tips.length < 6)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _tips.add(TextEditingController())),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add tip'),
                  style: TextButton.styleFrom(foregroundColor: kLinkBlue),
                ),
              ),
            label('Colour'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < reelThemes.length; i++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _theme = i),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: reelThemes[i],
                        ),
                        border: Border.all(
                          color: i == _theme ? ink : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: i == _theme
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
              ],
            ),
            label('Topic'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final topic in PostService.topics)
                  ChoiceChip(
                    label: Text(topic),
                    selected: topic == _topic,
                    showCheckmark: false,
                    selectedColor: kLinkBlue,
                    labelStyle: TextStyle(
                        color: topic == _topic ? Colors.white : ink,
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _topic = topic),
                  ),
              ],
            ),
            label('Caption'),
            TextField(
              controller: _reelCaption,
              minLines: 2,
              maxLines: 4,
              maxLength: 2200,
              style: TextStyle(fontSize: 14, color: ink),
              decoration: plain('Write a caption… (optional)', counter: ''),
            ),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 16, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Share general health information only. Never post '
                    'another person\'s name, photo or medical details.',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.35)),
              ),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
            ],
          ],
        );
        final showPreview = size.width >= 760;
        body = Column(
          children: [
            header(
              title: 'New health tip reel',
              leading: IconButton(
                tooltip: 'Back',
                onPressed: _sharing
                    ? null
                    : () => setState(() {
                          _error = null;
                          _step = _CreateStep.pick;
                        }),
                icon: Icon(Icons.arrow_back_rounded, color: ink),
              ),
              trailing: TextButton(
                onPressed: _sharing ? null : _shareReel,
                child: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Share',
                        style: TextStyle(
                            color: kLinkBlue, fontWeight: FontWeight.w700)),
              ),
            ),
            Divider(height: 1, color: divider),
            Expanded(
              child: showPreview
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: reelPreviewWidth,
                          child: ReelPlayer(
                            reel: _draftReel(account),
                            interactive: false,
                            captionOverlay: false,
                          ),
                        ),
                        VerticalDivider(width: 1, color: divider),
                        Expanded(child: form),
                      ],
                    )
                  : form,
            ),
          ],
        );
      case _CreateStep.done:
        body = Column(
          children: [
            header(title: _madeReel ? 'Reel shared' : 'Post shared'),
            Divider(height: 1, color: divider),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (_, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFFDB2777)],
                          ),
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 56),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                        _madeReel
                            ? 'Your reel has been shared.'
                            : 'Your post has been shared.',
                        style: TextStyle(fontSize: 20, color: ink)),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done',
                          style: TextStyle(
                              color: kLinkBlue, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: context.fdColor(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: width,
        height: square + 47,
        child: body,
      ),
    );
  }
}
