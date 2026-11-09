import 'dart:async';
import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../widgets/item_card.dart';
import 'add_item_screen.dart';
import 'item_details_screen.dart';
import 'profile_screen.dart';

class LostFoundScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  const LostFoundScreen({super.key, this.onProfileTap});
  @override State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  final _items = ItemService();
  final _auth = AuthService();
  final _search = TextEditingController();
  Timer? _debounce;
  List<ItemModel> _data = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _debounce?.cancel(); _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await _items.getItems(search: _search.text.trim());
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load items: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _onSearch(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final theme = Theme.of(context);
    return SafeArea(
      child: RefreshIndicator(color: theme.colorScheme.primary, onRefresh: _load,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverPadding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('nook.', style: theme.textTheme.displayLarge?.copyWith(fontSize: 31, color: theme.colorScheme.primary)),
                  const SizedBox(height: 2),
                  Text('A little place for your campus life.', style: theme.textTheme.bodyMedium),
                ])),
                Material(color: theme.colorScheme.surfaceContainerHighest, shape: const CircleBorder(), child: InkWell(
                  customBorder: const CircleBorder(), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: SizedBox(width: 44, height: 44, child: Center(child: Text(initial, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 17)))),
                )),
              ]),
              const SizedBox(height: 22),
              TextField(controller: _search, onChanged: _onSearch, decoration: InputDecoration(
                hintText: 'Search items, locations...', prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _search.clear(); _load(); setState(() {}); }),
              )),
              const SizedBox(height: 24),
              Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor.withValues(alpha: .5))),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Lost something?', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4), Text('Let your campus help you find it.', style: theme.textTheme.bodyMedium),
                  ])),
                  Icon(Icons.travel_explore_rounded, size: 38, color: theme.colorScheme.primary),
                ]),
              ),
              const SizedBox(height: 23),
              Row(children: [Text('Recently posted', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)), const Spacer(), Text('${_data.length} items', style: theme.textTheme.bodyMedium)]),
              const SizedBox(height: 13),
            ]),
          )),
          if (_loading)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (_data.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: LostFoundEmptyState())
          else
            SliverPadding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 105), sliver: SliverList.separated(
              itemCount: _data.length,
              itemBuilder: (_, i) => ItemCard(item: _data[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: _data[i]))).then((_) => _load())),
              separatorBuilder: (_, __) => const SizedBox(height: 15),
            )),
        ]),
      ),
    );
  }
}


class LostFoundEmptyState extends StatelessWidget {
  const LostFoundEmptyState({super.key});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(35), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 85, height: 85, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .13), shape: BoxShape.circle), child: Icon(Icons.search_off_rounded, size: 42, color: Theme.of(context).colorScheme.primary)),
    const SizedBox(height: 18), Text('Nothing here yet', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 5), Text('Be the first student to post a lost or found item.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
  ])));
}
