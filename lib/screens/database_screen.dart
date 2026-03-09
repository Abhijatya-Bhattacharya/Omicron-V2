import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/research_paper.dart';

/// Curated Research Database with PRISMA-based screening
class DatabaseScreen extends StatefulWidget {
  final List<ResearchPaper> papers;
  final ValueChanged<List<ResearchPaper>> onPapersChanged;

  const DatabaseScreen({
    super.key,
    required this.papers,
    required this.onPapersChanged,
  });

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  final _searchCtrl = TextEditingController();
  PrismaStage? _filterStage;
  String _sortField = 'year';
  bool _sortDesc = true;
  String? _filterTopic; // null = all topics
  bool _groupByTopic = true;
  final Set<String> _collapsedTopics = {}; // tracks which topic groups are collapsed
  bool _initialCollapseDone = false;

  /// Get all unique topics from papers
  List<String> get _allTopics {
    final topics = <String>{};
    for (final p in widget.papers) {
      topics.add(p.topic ?? 'Uncategorized');
    }
    final sorted = topics.toList()..sort();
    return sorted;
  }

  List<ResearchPaper> get _filteredPapers {
    var list = List<ResearchPaper>.from(widget.papers);

    // Filter by topic
    if (_filterTopic != null) {
      list = list.where((p) => (p.topic ?? 'Uncategorized') == _filterTopic).toList();
    }

    // Filter by PRISMA stage
    if (_filterStage != null) {
      list = list.where((p) => p.prismaStage == _filterStage).toList();
    }

    // Search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.authors.toLowerCase().contains(q) ||
            p.keywords.any((k) => k.toLowerCase().contains(q)) ||
            p.methodology.toLowerCase().contains(q) ||
            (p.year?.toString().contains(q) ?? false);
      }).toList();
    }

    // Sort
    list.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'title':
          cmp = a.title.compareTo(b.title);
          break;
        case 'authors':
          cmp = a.authors.compareTo(b.authors);
          break;
        case 'year':
        default:
          cmp = (a.year ?? 0).compareTo(b.year ?? 0);
      }
      return _sortDesc ? -cmp : cmp;
    });

    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _updatePaper(ResearchPaper updated) {
    final idx = widget.papers.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      widget.papers[idx] = updated;
      widget.onPapersChanged(widget.papers);
    }
  }

  void _removePaper(String id) {
    widget.papers.removeWhere((p) => p.id == id);
    widget.onPapersChanged(widget.papers);
  }

  void _addPaper(ResearchPaper paper) {
    widget.papers.add(paper);
    widget.onPapersChanged(widget.papers);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPapers;
    final stageCounts = <PrismaStage, int>{};
    for (final p in widget.papers) {
      stageCounts[p.prismaStage] = (stageCounts[p.prismaStage] ?? 0) + 1;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumb
                Row(
                  children: [
                    Text('Omicron',
                        style: GoogleFonts.interTight(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.chevron_right,
                          size: 14, color: AppTheme.textTertiary),
                    ),
                    Text('Research Database',
                        style: GoogleFonts.interTight(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Research Database',
                            style: AppTheme.displayMedium()),
                        const SizedBox(height: 4),
                        Text('Curated papers with PRISMA screening',
                            style: GoogleFonts.interTight(
                                fontSize: 14,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                    Row(
                      children: [
                        _buildStatBadge(
                            '${widget.papers.length}', 'Total', AppTheme.info),
                        const SizedBox(width: 8),
                        _buildStatBadge(
                            '${stageCounts[PrismaStage.included] ?? 0}',
                            'Included',
                            AppTheme.success),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _showAddPaperDialog,
                          icon:
                              const Icon(Icons.add_rounded, size: 18),
                          label: Text('Add Paper',
                              style: GoogleFonts.interTight(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(height: 1, color: AppTheme.divider),
                const SizedBox(height: 24),

                // PRISMA Stage filter chips
                _buildPrismaFilterBar(stageCounts),
                const SizedBox(height: 16),

                // Topic filter chips
                if (_allTopics.length > 1) ...[
                  _buildTopicFilterBar(),
                  const SizedBox(height: 16),
                ],

                // Search & Sort bar
                _buildSearchSortBar(),
                const SizedBox(height: 20),

                // Papers list - grouped by topic
                if (_groupByTopic && _filterTopic == null)
                  ..._buildGroupedPapersList(filtered)
                else
                  _buildFlatPapersList(filtered),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopicFilterBar() {
    final topics = _allTopics;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Group-by toggle
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _groupByTopic = !_groupByTopic),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _groupByTopic
                      ? AppTheme.primary.withOpacity(0.12)
                      : AppTheme.surfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _groupByTopic
                        ? AppTheme.primary.withOpacity(0.4)
                        : AppTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspaces_rounded,
                        size: 14,
                        color: _groupByTopic
                            ? AppTheme.primary
                            : AppTheme.textTertiary),
                    const SizedBox(width: 6),
                    Text('Group',
                        style: GoogleFonts.interTight(
                            fontSize: 11,
                            fontWeight: _groupByTopic
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _groupByTopic
                                ? AppTheme.primary
                                : AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filterTopic = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _filterTopic == null
                      ? AppTheme.primary.withOpacity(0.12)
                      : AppTheme.surfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _filterTopic == null
                        ? AppTheme.primary.withOpacity(0.4)
                        : AppTheme.border,
                  ),
                ),
                child: Text('All Topics',
                    style: GoogleFonts.interTight(
                        fontSize: 11,
                        fontWeight: _filterTopic == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _filterTopic == null
                            ? AppTheme.primary
                            : AppTheme.textSecondary)),
              ),
            ),
          ),
          // Topic chips
          ...topics.map((topic) {
            final isSelected = _filterTopic == topic;
            final count =
                widget.papers.where((p) => (p.topic ?? 'Uncategorized') == topic).length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filterTopic = isSelected ? null : topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2D7A8A).withOpacity(0.12)
                        : AppTheme.surfaceHover,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2D7A8A).withOpacity(0.4)
                          : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.topic_rounded,
                          size: 13,
                          color: isSelected
                              ? const Color(0xFF2D7A8A)
                              : AppTheme.textTertiary),
                      const SizedBox(width: 6),
                      Text(topic.length > 30 ? '${topic.substring(0, 30)}...' : topic,
                          style: GoogleFonts.interTight(
                              fontSize: 11,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF2D7A8A)
                                  : AppTheme.textSecondary)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2D7A8A).withOpacity(0.2)
                              : AppTheme.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('$count',
                            style: GoogleFonts.interTight(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFF2D7A8A)
                                    : AppTheme.textTertiary)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedPapersList(List<ResearchPaper> filtered) {
    // Group papers by topic
    final grouped = <String, List<ResearchPaper>>{};
    for (final p in filtered) {
      final topic = p.topic ?? 'Uncategorized';
      grouped.putIfAbsent(topic, () => []).add(p);
    }

    if (filtered.isEmpty) {
      return [_buildFlatPapersList(filtered)];
    }

    final sortedTopics = grouped.keys.toList()..sort();
    // Start all topics collapsed by default on first build only
    if (!_initialCollapseDone && sortedTopics.isNotEmpty) {
      _initialCollapseDone = true;
      _collapsedTopics.addAll(sortedTopics);
    }
    return sortedTopics.map((topic) {
      final papers = grouped[topic]!;
      final isCollapsed = _collapsedTopics.contains(topic);
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.glassSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isCollapsed) {
                          _collapsedTopics.remove(topic);
                        } else {
                          _collapsedTopics.add(topic);
                        }
                      });
                    },
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: isCollapsed ? -0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more_rounded,
                              size: 20, color: const Color(0xFF2D7A8A)),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.topic_rounded,
                            size: 16, color: const Color(0xFF2D7A8A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(topic.toUpperCase(),
                              style: AppTheme.labelSmall().copyWith(
                                  color: const Color(0xFF2D7A8A))),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D7A8A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${papers.length}',
                              style: GoogleFonts.interTight(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2D7A8A))),
                        ),
                      ],
                    ),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(height: 16),
                    ...papers.map((p) => _buildPaperCard(p)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFlatPapersList(List<ResearchPaper> filtered) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.glassSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('PAPERS', style: AppTheme.labelSmall()),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${filtered.length}',
                        style: GoogleFonts.interTight(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _buildEmptyState()
              else
                ...filtered.map((p) => _buildPaperCard(p)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: GoogleFonts.interTight(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.interTight(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildPrismaFilterBar(Map<PrismaStage, int> counts) {
    final stages = [
      (null, 'All', Icons.list_rounded, AppTheme.textSecondary),
      (PrismaStage.identified, 'Identified', Icons.search_rounded,
          AppTheme.info),
      (PrismaStage.screened, 'Screened', Icons.filter_list_rounded,
          AppTheme.warning),
      (PrismaStage.eligible, 'Eligible', Icons.check_circle_outline,
          const Color(0xFF2D7A8A)),
      (PrismaStage.included, 'Included', Icons.done_all_rounded,
          AppTheme.success),
      (PrismaStage.excluded, 'Excluded', Icons.cancel_outlined,
          AppTheme.error),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: stages.map((s) {
          final stage = s.$1;
          final label = s.$2;
          final icon = s.$3;
          final color = s.$4;
          final isSelected = _filterStage == stage;
          final count = stage == null
              ? widget.papers.length
              : (counts[stage] ?? 0);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filterStage = stage),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.15)
                      : AppTheme.surfaceHover,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? color.withOpacity(0.5)
                        : AppTheme.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 16,
                        color: isSelected ? color : AppTheme.textTertiary),
                    const SizedBox(width: 6),
                    Text(label,
                        style: GoogleFonts.interTight(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? color
                                : AppTheme.textSecondary)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.2)
                            : AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$count',
                          style: GoogleFonts.interTight(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? color
                                  : AppTheme.textTertiary)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchSortBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search papers by title, author, keyword...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortField,
              icon: const Icon(Icons.sort_rounded, size: 18),
              items: [
                DropdownMenuItem(
                    value: 'year',
                    child: Text('Year',
                        style: GoogleFonts.interTight(fontSize: 13))),
                DropdownMenuItem(
                    value: 'title',
                    child: Text('Title',
                        style: GoogleFonts.interTight(fontSize: 13))),
                DropdownMenuItem(
                    value: 'authors',
                    child: Text('Authors',
                        style: GoogleFonts.interTight(fontSize: 13))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _sortField = v);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            _sortDesc
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            size: 20,
          ),
          onPressed: () => setState(() => _sortDesc = !_sortDesc),
          tooltip: _sortDesc ? 'Newest first' : 'Oldest first',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.border)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.background,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.library_books_outlined,
                  size: 32, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 16),
            Text('No Papers Found', style: AppTheme.titleMedium()),
            const SizedBox(height: 8),
            Text(
                'Add papers manually or import from search results.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium()),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperCard(ResearchPaper paper) {
    final stageInfo = _stageInfo(paper.prismaStage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: stageInfo.$3.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(stageInfo.$2, size: 18, color: stageInfo.$3),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paper.title,
                        style: GoogleFonts.interTight(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(paper.authors,
                        style: GoogleFonts.interTight(
                            fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (paper.year != null)
                          _chip('${paper.year}', AppTheme.backgroundAlt,
                              AppTheme.textSecondary),
                        _chip(stageInfo.$1, stageInfo.$3.withOpacity(0.12),
                            stageInfo.$3),
                        if (paper.methodology.isNotEmpty)
                          _chip(paper.methodology, AppTheme.infoLight,
                              AppTheme.info),
                        ...paper.keywords.take(3).map((k) =>
                            _chip(k, AppTheme.warningLight, AppTheme.warning)),
                        if (paper.topic != null && paper.topic!.isNotEmpty && !_groupByTopic)
                          _chip(paper.topic!.length > 20
                              ? '${paper.topic!.substring(0, 20)}...'
                              : paper.topic!,
                              const Color(0xFF2D7A8A).withOpacity(0.12),
                              const Color(0xFF2D7A8A)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 18, color: AppTheme.textTertiary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onSelected: (v) => _handlePaperAction(v, paper),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'view', child: Text('View Details')),
                  const PopupMenuItem(
                      value: 'edit', child: Text('Edit')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'screen',
                      child: Text('Mark as Screened')),
                  const PopupMenuItem(
                      value: 'eligible',
                      child: Text('Mark as Eligible')),
                  const PopupMenuItem(
                      value: 'include',
                      child: Text('Mark as Included')),
                  const PopupMenuItem(
                      value: 'exclude',
                      child: Text('Mark as Excluded')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove',
                          style: TextStyle(color: AppTheme.error))),
                ],
              ),
            ],
          ),
          if (paper.abstract_.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(paper.abstract_,
                style: GoogleFonts.interTight(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                    height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          if (paper.exclusionReason != null &&
              paper.prismaStage == PrismaStage.excluded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppTheme.error),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('Reason: ${paper.exclusionReason}',
                        style: GoogleFonts.interTight(
                            fontSize: 11, color: AppTheme.error)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.interTight(
              fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  (String, IconData, Color) _stageInfo(PrismaStage stage) {
    switch (stage) {
      case PrismaStage.identified:
        return ('Identified', Icons.search_rounded, AppTheme.info);
      case PrismaStage.screened:
        return ('Screened', Icons.filter_list_rounded, AppTheme.warning);
      case PrismaStage.eligible:
        return ('Eligible', Icons.check_circle_outline, const Color(0xFF2D7A8A));
      case PrismaStage.included:
        return ('Included', Icons.done_all_rounded, AppTheme.success);
      case PrismaStage.excluded:
        return ('Excluded', Icons.cancel_outlined, AppTheme.error);
    }
  }

  void _handlePaperAction(String action, ResearchPaper paper) {
    switch (action) {
      case 'view':
        _showPaperDetailsDialog(paper);
        break;
      case 'edit':
        _showEditPaperDialog(paper);
        break;
      case 'screen':
        paper.prismaStage = PrismaStage.screened;
        paper.exclusionReason = null;
        _updatePaper(paper);
        setState(() {});
        break;
      case 'eligible':
        paper.prismaStage = PrismaStage.eligible;
        paper.exclusionReason = null;
        _updatePaper(paper);
        setState(() {});
        break;
      case 'include':
        paper.prismaStage = PrismaStage.included;
        paper.exclusionReason = null;
        _updatePaper(paper);
        setState(() {});
        break;
      case 'exclude':
        _showExcludeDialog(paper);
        break;
      case 'delete':
        _removePaper(paper.id);
        setState(() {});
        break;
    }
  }

  void _showExcludeDialog(ResearchPaper paper) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Exclude Paper',
            style: GoogleFonts.interTight(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Provide a reason for excluding this paper:',
                style: GoogleFonts.interTight(
                    fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Not relevant to research question',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              paper.prismaStage = PrismaStage.excluded;
              paper.exclusionReason =
                  ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : 'No reason provided';
              _updatePaper(paper);
              setState(() {});
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Exclude'),
          ),
        ],
      ),
    );
  }

  void _showPaperDetailsDialog(ResearchPaper paper) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.article_rounded,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Paper Details',
                  style: GoogleFonts.interTight(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Title', paper.title),
                _detailRow('Authors', paper.authors),
                _detailRow('Year', paper.year?.toString() ?? 'N/A'),
                _detailRow('Keywords', paper.keywords.join(', ')),
                _detailRow('Methodology', paper.methodology),
                _detailRow('Source', paper.source ?? 'N/A'),
                _detailRow('Country', paper.country ?? 'N/A'),
                _detailRow('PRISMA Stage', _stageInfo(paper.prismaStage).$1),
                _detailRow('Topic', paper.topic ?? 'Uncategorized'),
                if (paper.abstract_.isNotEmpty)
                  _detailRow('Abstract', paper.abstract_),
                if (paper.results.isNotEmpty)
                  _detailRow('Results', paper.results),
                if (paper.exclusionReason != null)
                  _detailRow('Exclusion Reason', paper.exclusionReason!),
              ],
            ),
          ),
        ),
        actions: [
          if (paper.url != null && paper.url!.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                launchUrl(Uri.parse(paper.url!), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('Open Paper',
                  style: GoogleFonts.interTight(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () {
              final query = Uri.encodeComponent(paper.title);
              final url = 'https://scholar.google.com/scholar?q=$query';
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.school_rounded, size: 16),
            label: Text('Google Scholar',
                style: GoogleFonts.interTight(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.interTight(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textTertiary,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.interTight(
                  fontSize: 13, color: AppTheme.textPrimary, height: 1.4)),
        ],
      ),
    );
  }

  void _showAddPaperDialog() {
    _showEditPaperDialog(null);
  }

  void _showEditPaperDialog(ResearchPaper? existing) {
    final titleC = TextEditingController(text: existing?.title ?? '');
    final authorsC = TextEditingController(text: existing?.authors ?? '');
    final yearC =
        TextEditingController(text: existing?.year?.toString() ?? '');
    final keywordsC =
        TextEditingController(text: existing?.keywords.join(', ') ?? '');
    final abstractC = TextEditingController(text: existing?.abstract_ ?? '');
    final methodC = TextEditingController(text: existing?.methodology ?? '');
    final resultsC = TextEditingController(text: existing?.results ?? '');
    final countryC = TextEditingController(text: existing?.country ?? '');
    final sourceC = TextEditingController(text: existing?.source ?? '');
    final urlC = TextEditingController(text: existing?.url ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Add Paper' : 'Edit Paper',
            style: GoogleFonts.interTight(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField('Title *', titleC),
                _dialogField('Authors *', authorsC),
                Row(
                  children: [
                    Expanded(child: _dialogField('Year', yearC)),
                    const SizedBox(width: 12),
                    Expanded(child: _dialogField('Country', countryC)),
                  ],
                ),
                _dialogField('Keywords (comma-separated)', keywordsC),
                _dialogField('Methodology', methodC),
                _dialogField('Source / Journal', sourceC),
                _dialogField('URL', urlC),
                _dialogField('Abstract', abstractC, maxLines: 3),
                _dialogField('Results', resultsC, maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleC.text.trim().isEmpty || authorsC.text.trim().isEmpty) {
                return;
              }
              final keywords = keywordsC.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              if (existing != null) {
                existing.title = titleC.text.trim();
                existing.authors = authorsC.text.trim();
                existing.year = int.tryParse(yearC.text.trim());
                existing.keywords = keywords;
                existing.abstract_ = abstractC.text.trim();
                existing.methodology = methodC.text.trim();
                existing.results = resultsC.text.trim();
                existing.country = countryC.text.trim().isNotEmpty
                    ? countryC.text.trim()
                    : null;
                existing.source = sourceC.text.trim().isNotEmpty
                    ? sourceC.text.trim()
                    : null;
                existing.url =
                    urlC.text.trim().isNotEmpty ? urlC.text.trim() : null;
                _updatePaper(existing);
              } else {
                _addPaper(ResearchPaper(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: titleC.text.trim(),
                  authors: authorsC.text.trim(),
                  year: int.tryParse(yearC.text.trim()),
                  keywords: keywords,
                  abstract_: abstractC.text.trim(),
                  methodology: methodC.text.trim(),
                  results: resultsC.text.trim(),
                  country: countryC.text.trim().isNotEmpty
                      ? countryC.text.trim()
                      : null,
                  source: sourceC.text.trim().isNotEmpty
                      ? sourceC.text.trim()
                      : null,
                  url: urlC.text.trim().isNotEmpty ? urlC.text.trim() : null,
                  prismaStage: PrismaStage.identified,
                ));
              }
              setState(() {});
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: GoogleFonts.interTight(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.interTight(fontSize: 12, color: AppTheme.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
