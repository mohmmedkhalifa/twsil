import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'api.dart';
import 'theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final bool danger;
  final bool warning;
  const StatusBadge({super.key, required this.label, this.color, this.danger = false, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? (danger ? Colors.red : warning ? Colors.orange : Colors.green);
    return Chip(
      label: Text(label),
      backgroundColor: c.withValues(alpha: .12),
      labelStyle: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.bold),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        ],
      ),
    );
  }
}

class PaginationBar extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;
  const PaginationBar({super.key, required this.page, required this.pageCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: page > 1 ? () => onChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
          Text('صفحة $page من $pageCount',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          IconButton(
            onPressed: page < pageCount ? () => onChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the image at full size inside a zoomable dialog.
void showImageViewer(BuildContext context, String url, String title) {
  final fullUrl = AApi.instance.imageUrl(url);
  showDialog(
    context: context,
    builder: (c) => Dialog(
      child: Stack(
        children: [
          InteractiveViewer(
            maxScale: 6,
            child: Image.network(
              fullUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image, size: 44, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('تعذر تحميل $title', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(c),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Clickable document thumbnail used in detail pages.
class DocumentThumb extends StatelessWidget {
  final String url;
  final String title;
  const DocumentThumb({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || url == 'null') {
      return Container(
        height: 110,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Text('لم يتم إرفاق $title', style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
      );
    }
    final fullUrl = AApi.instance.imageUrl(url);
    return InkWell(
      onTap: () => showImageViewer(context, url, title),
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Image.network(
              fullUrl,
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 110,
                color: Colors.grey.shade100,
                alignment: Alignment.center,
                child: Text('تعذر تحميل $title', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Container(height: 170, alignment: Alignment.center, child: const CircularProgressIndicator()),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section container used by detail pages.
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SectionCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Back button used at the top of detail pages (works with browser history).
class BackToListButton extends StatelessWidget {
  final String listPath;
  const BackToListButton({super.key, required this.listPath});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextButton.icon(
        onPressed: () => context.go(listPath),
        icon: const Icon(Icons.arrow_back_ios_new, size: 15),
        label: const Text('رجوع'),
      ),
    );
  }
}
