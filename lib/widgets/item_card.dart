import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item_model.dart';
import 'item_badges.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const ItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final resolved = item.status == 'RESOLVED';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 175,
              width: double.infinity,
              child: item.imageUrl == null || item.imageUrl!.isEmpty
                  ? Container(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Icon(Icons.image_outlined, size: 48, color: muted),
                ),
              )
                  : Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, size: 42, color: muted),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TypeBadge(type: item.type),
                      if (resolved) ...[
                        const SizedBox(width: 8),
                        const ResolvedBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: muted),
                      const SizedBox(width: 4),
                      Expanded(child: Text(item.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: muted),
                      const SizedBox(width: 5),
                      Text(DateFormat('dd MMM yyyy • hh:mm a').format(item.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  if (item.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (item.userName != null && item.userName!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: scheme.primary,
                          child: Text(item.userName!.trim().isEmpty ? '?' : item.userName!.trim()[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item.userName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
