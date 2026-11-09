
import 'package:flutter/material.dart';

import '../models/campus_group.dart';
import '../models/join_request.dart';
import '../services/group_service.dart';
import '../widgets/join_requests_inbox.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final GroupService _service = GroupService();
  final TextEditingController _search = TextEditingController();

  List<CampusGroup> _groups = [];
  Map<String, String> _requestStatuses = {};
  final Set<String> _busyGroups = {};

  // Pending requests for every group the current user manages.
  List<JoinRequest> _pendingRequests = [];
  // requestId -> true while approving / false while rejecting.
  final Map<String, bool> _reviewing = {};
  bool _requestsExpanded = false;

  bool _loading = true;
  bool _myGroupsOnly = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // Display messages to the user.
  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  // Load groups from Supabase.
  Future<void> _loadGroups({bool showSpinner = true}) async {
    if (!mounted) return;

    if (showSpinner) {
      setState(() {
        _loading = true;
      });
    }

    debugPrint('GROUPS: Loading started');

    try {
      final results = await Future.wait([
        _service.getCampusGroups(),
        _service.getMyJoinRequestStatuses(),
        // A failure here must not stop the group list from loading.
        _service.getPendingRequestsForManagedGroups().catchError((Object e) {
          debugPrint('JOIN REQUESTS ERROR: $e');
          return <JoinRequest>[];
        }),
      ]);

      final groups = results[0] as List<CampusGroup>;
      final statuses = results[1] as Map<String, String>;
      final requests = results[2] as List<JoinRequest>;

      debugPrint('GROUPS: Loaded ${groups.length} groups');

      if (!mounted) return;

      setState(() {
        _groups = groups;
        _requestStatuses = statuses;
        _pendingRequests = requests;
        if (requests.isEmpty) _requestsExpanded = false;
      });
    } catch (e, stackTrace) {
      debugPrint('GROUPS ERROR: $e');
      debugPrint('$stackTrace');

      _message('Could not load groups: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Open the create group dialog.
  Future<void> _createGroup() async {
    if (_creating) return;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Create a Group'),

            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Group name',
                      hintText: 'e.g. Coding Club',
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'What is this group about?',
                    ),
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),

              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a group name.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Create Group'),
              ),
            ],
          );
        },
      );

      if (result != true || !mounted) return;

      final name = nameController.text.trim();
      final description = descriptionController.text.trim();

      setState(() {
        _creating = true;
      });

      debugPrint('GROUP CREATE: Starting...');
      debugPrint('GROUP CREATE: Name = $name');

      await _service.createGroup(
        name: name,
        description: description,
      );

      debugPrint('GROUP CREATE: Successfully created');

      if (!mounted) return;

      _message('Group created successfully!');

      await _loadGroups();

    } catch (e, stackTrace) {
      debugPrint('GROUP CREATE ERROR: $e');
      debugPrint('$stackTrace');

      _message('Could not create group: $e');

    } finally {
      nameController.dispose();
      descriptionController.dispose();

      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  // Join or leave a group.
  Future<void> _toggleMembership(CampusGroup group) async {
    final id = group.id;

    if (_busyGroups.contains(id)) return;

    setState(() {
      _busyGroups.add(id);
    });

    try {
      if (group.joined) {
        await _service.leaveGroup(id);
        _message('You left the group.');
      } else {
        await _service.requestToJoinGroup(id);
        _message('Your join request has been sent.');
      }

      await _loadGroups();
    } catch (e, stackTrace) {
      debugPrint('MEMBERSHIP ERROR: $e');
      debugPrint('$stackTrace');

      _message('Could not update membership: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busyGroups.remove(id);
        });
      }
    }
  }


  // Approve or reject a request straight from the inbox.
  Future<void> _reviewRequest(JoinRequest request, bool approve) async {
    if (_reviewing.containsKey(request.id)) return;

    setState(() {
      _reviewing[request.id] = approve;
    });

    try {
      await _service.reviewJoinRequest(
        requestId: request.id,
        approve: approve,
      );

      if (!mounted) return;

      // Update the count immediately instead of waiting for a reload.
      setState(() {
        _pendingRequests.removeWhere((r) => r.id == request.id);
        if (_pendingRequests.isEmpty) _requestsExpanded = false;
      });

      _message(
        approve
            ? '${request.requesterName} was added to ${request.groupLabel}.'
            : 'Request from ${request.requesterName} rejected.',
      );

      // Member counts and "joined" state may have changed.
      await _loadGroups(showSpinner: false);
    } catch (e) {
      debugPrint('REVIEW REQUEST ERROR: $e');
      _message('Could not review request: $e');

      // It may already have been handled by another admin, so resync.
      await _loadGroups(showSpinner: false);
    } finally {
      if (mounted) {
        setState(() {
          _reviewing.remove(request.id);
        });
      }
    }
  }

  // Open the selected group.
  Future<void> _openGroup(CampusGroup group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(group: group),
      ),
    );

    // Requests may have been handled inside the group, so refresh quietly.
    if (mounted) {
      await _loadGroups(showSpinner: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final query = _search.text.trim().toLowerCase();

    final filteredGroups = _groups.where((group) {
      final matchesSearch =
          group.name.toLowerCase().contains(query) ||
              group.description.toLowerCase().contains(query);

      final matchesMembership =
          !_myGroupsOnly || group.joined;

      return matchesSearch && matchesMembership;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGroups,

          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.fromLTRB(20, 24, 20, 35),

            children: [
              // PAGE HEADING
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Groups',
                          style: theme.textTheme.displayLarge,
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Find your people on campus.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    width: 115,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        maximumSize: const Size(115, 48),
                      ),

                      onPressed: _creating ? null : _createGroup,

                      icon: _creating
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.add),

                      label: Text(
                        _creating ? 'Creating' : 'Create',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // JOIN REQUESTS INBOX (hidden when nothing is pending)
              if (_pendingRequests.isNotEmpty) ...[
                JoinRequestsInbox(
                  requests: _pendingRequests,
                  expanded: _requestsExpanded,
                  reviewing: _reviewing,
                  onToggle: () {
                    setState(() {
                      _requestsExpanded = !_requestsExpanded;
                    });
                  },
                  onReview: _reviewRequest,
                ),

                const SizedBox(height: 25),
              ],

              // SEARCH FIELD
              TextField(
                controller: _search,

                onChanged: (_) {
                  setState(() {});
                },

                decoration: InputDecoration(
                  hintText: 'Search communities...',
                  prefixIcon: const Icon(Icons.search),

                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  )
                      : null,
                ),
              ),

              const SizedBox(height: 20),

              // DISCOVER / MY GROUPS FILTER
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Discover'),
                    icon: Icon(Icons.explore_outlined),
                  ),

                  ButtonSegment<bool>(
                    value: true,
                    label: Text('My Groups'),
                    icon: Icon(Icons.groups_outlined),
                  ),
                ],

                selected: {_myGroupsOnly},

                onSelectionChanged: (selection) {
                  setState(() {
                    _myGroupsOnly = selection.first;
                  });
                },
              ),

              const SizedBox(height: 25),

              // GROUP LIST HEADING
              Text(
                _myGroupsOnly
                    ? 'Your communities'
                    : 'Explore communities',

                style: theme.textTheme.titleLarge,
              ),

              const SizedBox(height: 5),

              Text(
                '${filteredGroups.length} communities',

                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: 18),

              // LOADING STATE
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(35),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )

              // EMPTY STATE
              else if (filteredGroups.isEmpty)
                _EmptyGroups(
                  myGroupsOnly: _myGroupsOnly,
                  hasSearch: query.isNotEmpty,
                )

              // GROUP CARDS
              else
                ...filteredGroups.map(
                      (group) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),

                      child: _GroupCard(
                        group: group,

                        requestStatus: _requestStatuses[group.id],

                        busy: _busyGroups.contains(group.id),

                        onMembershipTap: () {
                          _toggleMembership(group);
                        },

                        onOpen: () {
                          _openGroup(group);
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}


// EMPTY GROUPS WIDGET
class _EmptyGroups extends StatelessWidget {
  final bool myGroupsOnly;
  final bool hasSearch;

  const _EmptyGroups({
    required this.myGroupsOnly,
    required this.hasSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String title;
    String subtitle;

    if (hasSearch) {
      title = 'No matching groups';
      subtitle = 'Try searching with a different name.';
    } else if (myGroupsOnly) {
      title = 'You have not joined any groups.';
      subtitle = 'Explore communities and join one.';
    } else {
      title = 'No communities yet.';
      subtitle = 'Be the first to create a campus community!';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 45),

      child: Column(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 55,
            color: theme.colorScheme.primary,
          ),

          const SizedBox(height: 16),

          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}


// GROUP CARD WIDGET

class _GroupCard extends StatelessWidget {
  final String? requestStatus;
  final CampusGroup group;
  final bool busy;
  final VoidCallback onMembershipTap;
  final VoidCallback onOpen;

  const _GroupCard({
    required this.requestStatus,
    required this.group,
    required this.busy,
    required this.onMembershipTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String buttonText;

    if (group.joined) {
      buttonText = 'Leave';
    } else if (requestStatus == 'pending') {
      buttonText = 'Requested';
    } else {
      buttonText = 'Request to Join';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                    theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.groups,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),

                  Icon(
                    Icons.arrow_forward_ios,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                group.description.isEmpty
                    ? 'No description provided.'
                    : group.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    '${group.memberCount} members',
                    style: theme.textTheme.bodySmall,
                  ),

                  const Spacer(),

                  SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed:
                      busy || requestStatus == 'pending'
                          ? null
                          : onMembershipTap,
                      child: busy
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : Text(buttonText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}