import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// 全螢幕照片檢視 — 支援雙指縮放、左右滑動、下拉關閉
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroTag,
  });

  final List<String> images;
  final int initialIndex;
  final String? heroTag;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _ctrl;
  late int _index;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dismissProgress = (_dragOffset.abs() / 200).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 1 - dismissProgress),
      body: GestureDetector(
        onVerticalDragUpdate: (d) => setState(() => _dragOffset += d.delta.dy),
        onVerticalDragEnd: (_) {
          if (_dragOffset.abs() > 120) {
            context.pop();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                pageController: _ctrl,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                backgroundDecoration:
                    const BoxDecoration(color: Colors.transparent),
                builder: (_, i) => PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(widget.images[i]),
                  heroAttributes: widget.heroTag != null && i == widget.initialIndex
                      ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                      : null,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  initialScale: PhotoViewComputedScale.contained,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.4),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => context.pop(),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_index + 1} / ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 32,
                child: Center(
                  child: SmoothPageIndicator(
                    controller: _ctrl,
                    count: widget.images.length,
                    effect: const ExpandingDotsEffect(
                      dotHeight: 6,
                      dotWidth: 6,
                      expansionFactor: 3,
                      spacing: 4,
                      activeDotColor: Colors.white,
                      dotColor: Colors.white38,
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
