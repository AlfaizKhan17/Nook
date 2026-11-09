import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/item_model.dart';
import '../services/item_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/contact_utils.dart';
import '../widgets/item_badges.dart';

class ItemDetailsScreen extends StatefulWidget {
  final ItemModel item;
  const ItemDetailsScreen({super.key, required this.item});
  @override State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  final _service = ItemService();
  final _storage = StorageService();
  bool _busy = false;

  ItemModel get _item => widget.item;
  bool get _owner => Supabase.instance.client.auth.currentUser?.id == _item.userId;
  bool get _resolved => _item.status == 'RESOLVED';
  bool get _hasImage => _item.imageUrl != null && _item.imageUrl!.isNotEmpty;
  String get _heroTag => 'item-image-${_item.id}';

  // ---------------------------------------------------------------- actions

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return yes == true;
  }

  Future<void> _resolve() async {
    final ok = await _confirm(
      title: 'Mark as resolved?',
      message: 'The listing will be removed from the public board. You can still see it in My Posts.',
      action: 'Mark resolved',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _service.markResolved(_item.id);
      if (!mounted) return;
      _show('Marked as resolved.');
      Navigator.pop(context);
    } catch (e) {
      _show('Could not update item: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await _confirm(
      title: 'Delete post?',
      message: 'This action cannot be undone.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _service.deleteItem(_item.id);
      if (_hasImage) await _storage.deleteImage(_item.imageUrl!);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _show('Could not delete item: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Uri? uri, String failure) async {
    if (uri == null) {
      _show(failure);
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _show(failure);
    } catch (_) {
      _show(failure);
    }
  }

  void _call() => _open(ContactUtils.telUri(_item.userPhone), 'Could not start a call.');

  void _whatsapp() => _open(
        ContactUtils.whatsappUri(
          _item.userPhone,
          ContactUtils.contactMessage(itemType: _item.type, title: _item.title),
          defaultCountryCode: AppConfig.defaultCountryCode,
        ),
        'Could not open WhatsApp.',
      );

  void _email() => _open(
        ContactUtils.mailUri(
          _item.userEmail,
          subject: ContactUtils.mailSubject(itemType: _item.type, title: _item.title),
          body: ContactUtils.contactMessage(itemType: _item.type, title: _item.title),
        ),
        'Could not open your email app.',
      );

  void _openImage() {
    if (!_hasImage) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FullImageScreen(url: _item.imageUrl!, heroTag: _heroTag)),
    );
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final created = _item.createdAt.toLocal();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 330,
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                GestureDetector(onTap: _openImage, child: _hero()),
                // Keeps the back arrow readable over bright photos.
                const Positioned(
                  top: 0, left: 0, right: 0, height: 110,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x99000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hasImage)
                  const Positioned(
                    right: 14, bottom: 34,
                    child: IgnorePointer(child: Icon(Icons.zoom_out_map_rounded, color: Colors.white70, size: 20)),
                  ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            // The sheet takes the scaffold colour (not a fixed light colour) so
            // theme text stays readable in both light and dark mode.
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 35),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  TypeBadge(type: _item.type),
                  if (_resolved) ...[const SizedBox(width: 8), const ResolvedBadge()],
                  const Spacer(),
                  Text(ContactUtils.timeAgo(created), style: theme.textTheme.bodySmall),
                ]),
                const SizedBox(height: 12),
                Text(_item.title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 15),
                _info(Icons.location_on_outlined, _item.location.isEmpty ? 'Location not specified' : _item.location),
                const SizedBox(height: 9),
                _info(Icons.schedule_rounded, DateFormat('dd MMM yyyy • hh:mm a').format(created)),
                const SizedBox(height: 22),
                Text('Description', style: theme.textTheme.titleMedium),
                const SizedBox(height: 7),
                Text(
                  _item.description.isEmpty ? 'No description provided.' : _item.description,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
                const SizedBox(height: 22),
                Text('Posted by', style: theme.textTheme.titleMedium),
                const SizedBox(height: 9),
                _posterCard(theme, scheme),
                if (_owner) ...[
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy || _resolved ? null : _resolve,
                    child: Text(_resolved ? 'Already Resolved' : 'Mark as Resolved'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      foregroundColor: AppColors.lost,
                      side: const BorderSide(color: AppColors.lost),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    if (!_hasImage) return _imagePlaceholder(broken: false);
    return Hero(
      tag: _heroTag,
      child: Image.network(
        _item.imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const ColoredBox(color: AppColors.ink, child: Center(child: CircularProgressIndicator(color: Colors.white54))),
        errorBuilder: (_, __, ___) => _imagePlaceholder(broken: true),
      ),
    );
  }

  Widget _imagePlaceholder({required bool broken}) => ColoredBox(
        color: AppColors.ink,
        child: Center(
          child: Icon(
            broken ? Icons.broken_image_outlined : Icons.image_outlined,
            color: Colors.white54,
            size: 65,
          ),
        ),
      );

  Widget _posterCard(ThemeData theme, ColorScheme scheme) {
    final name = (_item.userName ?? '').trim();
    final phone = (_item.userPhone ?? '').trim();
    final email = (_item.userEmail ?? '').trim();

    final canCall = ContactUtils.telUri(phone) != null;
    final canWhatsapp = ContactUtils.whatsappNumber(phone) != null;
    final canEmail = ContactUtils.isValidEmail(email);
    final showActions = !_owner && (canCall || canWhatsapp || canEmail);
    final noContact = !_owner && phone.isEmpty && email.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: scheme.primary,
              child: Text(
                name.isEmpty ? 'S' : name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Student' : name, style: theme.textTheme.titleMedium),
                // Selectable so a long-press copies the number / address.
                if (phone.isNotEmpty) SelectableText('☎ $phone', style: theme.textTheme.bodyMedium),
                if (email.isNotEmpty) SelectableText(email, style: theme.textTheme.bodyMedium),
              ]),
            ),
          ]),
          if (showActions) ...[
            const SizedBox(height: 14),
            Row(children: [
              if (canCall) Expanded(child: _ContactAction(icon: Icons.call_rounded, label: 'Call', onTap: _call)),
              if (canCall && (canWhatsapp || canEmail)) const SizedBox(width: 8),
              if (canWhatsapp)
                Expanded(child: _ContactAction(icon: Icons.chat_bubble_rounded, label: 'WhatsApp', onTap: _whatsapp)),
              if (canWhatsapp && canEmail) const SizedBox(width: 8),
              if (canEmail) Expanded(child: _ContactAction(icon: Icons.mail_rounded, label: 'Email', onTap: _email)),
            ]),
          ],
          if (noContact) ...[
            const SizedBox(height: 10),
            Text('This student has not shared contact details.', style: theme.textTheme.bodySmall),
          ],
        ]),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ]);
}

/// iOS-style quick action: icon over a short label on a tinted tile.
class _ContactAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: primary, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom photo viewer.
class _FullImageScreen extends StatelessWidget {
  final String url;
  final String heroTag;
  const _FullImageScreen({required this.url, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white54)),
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
