import 'package:flutter/material.dart';
import '../models/join_request.dart';
import '../utils/contact_utils.dart';

/// One pending join request with Approve / Reject buttons.
///
/// Shared by the Groups inbox and each group's own management section so both
/// look and behave the same.
class JoinRequestTile extends StatelessWidget {
  final JoinRequest request;

  /// True while a decision for this request is being sent.
  final bool busy;

  /// Which button shows the spinner while [busy]: true = Approve, false = Reject.
  final bool? approving;

  /// The inbox spans many groups so it names the group; a group's own screen
  /// does not need to.
  final bool showGroupName;

  final VoidCallback onApprove;
  final VoidCallback onReject;

  const JoinRequestTile({
    super.key,
    required this.request,
    required this.onApprove,
    required this.onReject,
    this.busy = false,
    this.approving,
    this.showGroupName = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = request.requesterName;
    final created = request.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Text(
              name.isEmpty ? 'S' : name[0].toUpperCase(),
              style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
              if (showGroupName && request.groupName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Icon(Icons.groups_outlined, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ]),
                ),
              if (created != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Requested ${ContactUtils.timeAgo(created)}', style: theme.textTheme.bodySmall),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          const _PendingChip(),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : onReject,
              child: busy && approving == false ? const _Spinner() : const Text('Reject'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : onApprove,
              child: busy && approving != false ? const _Spinner(onFilled: true) : const Text('Approve'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text('Pending', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _Spinner extends StatelessWidget {
  final bool onFilled;
  const _Spinner({this.onFilled = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: onFilled ? Colors.white : null),
      );
}
