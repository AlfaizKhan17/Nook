import 'package:flutter/material.dart';
import '../models/join_request.dart';
import 'join_request_tile.dart';

/// Notification-style card for the top of the Groups screen.
///
/// Collapsed it reads "You have 3 requests waiting for approval" with a count
/// badge. Tapping expands the list so each request can be approved or rejected
/// without opening the group. Renders nothing when there are no requests.
class JoinRequestsInbox extends StatelessWidget {
  final List<JoinRequest> requests;
  final bool expanded;

  /// requestId -> true while approving / false while rejecting.
  final Map<String, bool> reviewing;

  final VoidCallback onToggle;
  final void Function(JoinRequest request, bool approve) onReview;

  const JoinRequestsInbox({
    super.key,
    required this.requests,
    required this.expanded,
    required this.reviewing,
    required this.onToggle,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = requests.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .12), shape: BoxShape.circle),
                child: Icon(Icons.notifications_active_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Join requests', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    count == 1
                        ? 'You have 1 request waiting for approval'
                        : 'You have $count requests waiting for approval',
                    style: theme.textTheme.bodyMedium,
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? .5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: scheme.onSurfaceVariant),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Divider(),
                    const SizedBox(height: 12),
                    Text('Pending requests', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    for (final request in requests)
                      JoinRequestTile(
                        key: ValueKey(request.id),
                        request: request,
                        busy: reviewing.containsKey(request.id),
                        approving: reviewing[request.id],
                        onApprove: () => onReview(request, true),
                        onReject: () => onReview(request, false),
                      ),
                    Text('Approve or reject each request here.', style: theme.textTheme.bodySmall),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}
