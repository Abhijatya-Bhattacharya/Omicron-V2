import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart';
import '../models/research_paper.dart';

/// Trend Analysis screen with auto-generated charts from collected papers
class TrendAnalysisScreen extends StatefulWidget {
  final List<ResearchPaper> papers;
  final Map<String, dynamic>? llmTrendInsights;

  const TrendAnalysisScreen({super.key, required this.papers, this.llmTrendInsights});

  @override
  State<TrendAnalysisScreen> createState() => _TrendAnalysisScreenState();
}

class _TrendAnalysisScreenState extends State<TrendAnalysisScreen> {
  String? _selectedTopic; // null = all topics
  final Set<String> _collapsedTrendTopics = {}; // tracks collapsed topic groups
  bool _initialTrendCollapseDone = false;

  List<String> get _allTopics {
    final topics = <String>{};
    for (final p in widget.papers) {
      if (p.prismaStage != PrismaStage.excluded) {
        topics.add(p.topic ?? 'Uncategorized');
      }
    }
    final sorted = topics.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    // Only include non-excluded papers for trend analysis
    var papers =
        widget.papers.where((p) => p.prismaStage != PrismaStage.excluded).toList();

    // Filter by selected topic
    if (_selectedTopic != null) {
      papers = papers.where((p) => (p.topic ?? 'Uncategorized') == _selectedTopic).toList();
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
                    Text('Trend Analysis',
                        style: GoogleFonts.interTight(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trend Analysis', style: AppTheme.displayMedium()),
                    const SizedBox(height: 4),
                    Text(
                        'Auto-generated graphs from collected research papers',
                        style: GoogleFonts.interTight(
                            fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 24),
                Container(height: 1, color: AppTheme.divider),
                const SizedBox(height: 24),

                // Topic filter chips
                if (_allTopics.length > 1) ...[
                  _buildTopicFilterBar(),
                  const SizedBox(height: 24),
                ],

                // LLM-generated trend insights
                if (widget.llmTrendInsights != null) ...[
                  _buildLlmInsights(widget.llmTrendInsights!),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 8),

                if (papers.isEmpty)
                  _buildEmptyState()
                else
                  ..._buildGroupedTrendCharts(papers),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupedTrendCharts(List<ResearchPaper> allPapers) {
    // Group papers by topic
    final grouped = <String, List<ResearchPaper>>{};
    for (final p in allPapers) {
      final topic = p.topic ?? 'Uncategorized';
      grouped.putIfAbsent(topic, () => []).add(p);
    }

    final sortedTopics = grouped.keys.toList()..sort();

    // Initialize all collapsed by default (once)
    if (!_initialTrendCollapseDone && sortedTopics.isNotEmpty) {
      _initialTrendCollapseDone = true;
      _collapsedTrendTopics.addAll(sortedTopics);
    }

    return sortedTopics.map((topic) {
      final papers = grouped[topic]!;
      final isCollapsed = _collapsedTrendTopics.contains(topic);
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
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
                          _collapsedTrendTopics.remove(topic);
                        } else {
                          _collapsedTrendTopics.add(topic);
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
                          child: Text('${papers.length} papers',
                              style: GoogleFonts.interTight(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2D7A8A))),
                        ),
                      ],
                    ),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(height: 20),
                    _buildChartsForPapers(papers),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildChartsForPapers(List<ResearchPaper> papers) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPublicationsPerYear(papers)),
            const SizedBox(width: 24),
            Expanded(child: _buildMethodologyChart(papers)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildKeywordFrequency(papers)),
            const SizedBox(width: 24),
            Expanded(child: _buildCountryContribution(papers)),
          ],
        ),
      ],
    );
  }

  Widget _buildTopicFilterBar() {
    final topics = _allTopics;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTopic = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTopic == null
                      ? AppTheme.primary.withOpacity(0.12)
                      : AppTheme.surfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedTopic == null
                        ? AppTheme.primary.withOpacity(0.4)
                        : AppTheme.border,
                  ),
                ),
                child: Text('All Topics',
                    style: GoogleFonts.interTight(
                        fontSize: 11,
                        fontWeight: _selectedTopic == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedTopic == null
                            ? AppTheme.primary
                            : AppTheme.textSecondary)),
              ),
            ),
          ),
          ...topics.map((topic) {
            final isSelected = _selectedTopic == topic;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedTopic = isSelected ? null : topic),
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

  Widget _buildLlmInsights(Map<String, dynamic> insights) {
    final overview = insights['overview']?.toString() ?? '';
    final emerging = insights['emerging_topics'];
    final declining = insights['declining_topics'];
    final methodTrends = insights['methodological_trends']?.toString() ?? '';
    final futureDir = insights['future_directions']?.toString() ?? '';
    final keyInsight = insights['key_insight']?.toString() ?? '';

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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 18, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('AI-GENERATED TREND INSIGHTS',
                      style: AppTheme.labelSmall()
                          .copyWith(color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 20),
              if (overview.isNotEmpty) ...[
                Text(overview,
                    style: GoogleFonts.interTight(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.5)),
                const SizedBox(height: 16),
              ],
              if (keyInsight.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_rounded,
                          size: 16, color: AppTheme.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(keyInsight,
                            style: GoogleFonts.interTight(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (emerging is List && emerging.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EMERGING TOPICS',
                              style: GoogleFonts.interTight(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.success,
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: emerging
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successLight,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.trending_up_rounded,
                                              size: 12, color: AppTheme.success),
                                          const SizedBox(width: 4),
                                          Text(t.toString(),
                                              style: GoogleFonts.interTight(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.success)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  if (declining is List && declining.isNotEmpty) ...[
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DECLINING TOPICS',
                              style: GoogleFonts.interTight(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.error,
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: declining
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorLight,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.trending_down_rounded,
                                              size: 12, color: AppTheme.error),
                                          const SizedBox(width: 4),
                                          Text(t.toString(),
                                              style: GoogleFonts.interTight(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.error)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (methodTrends.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('METHODOLOGICAL TRENDS',
                    style: GoogleFonts.interTight(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textTertiary,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(methodTrends,
                    style: GoogleFonts.interTight(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4)),
              ],
              if (futureDir.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('FUTURE DIRECTIONS',
                    style: GoogleFonts.interTight(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textTertiary,
                        letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(futureDir,
                    style: GoogleFonts.interTight(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bar_chart_rounded,
                size: 40, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 20),
          Text('No Data Available', style: AppTheme.titleMedium()),
          const SizedBox(height: 8),
          Text(
              'Add papers to the Research Database\nto see trend analysis charts.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium()),
        ],
      ),
    );
  }

  // --- Publications per Year ---
  Widget _buildPublicationsPerYear(List<ResearchPaper> papers) {
    final yearCounts = <int, int>{};
    for (final p in papers) {
      if (p.year != null) {
        yearCounts[p.year!] = (yearCounts[p.year!] ?? 0) + 1;
      }
    }

    if (yearCounts.isEmpty) {
      return _chartCard('Publications per Year', _noDataWidget());
    }

    final sortedYears = yearCounts.keys.toList()..sort();
    final maxCount =
        yearCounts.values.reduce((a, b) => a > b ? a : b).toDouble();

    return _chartCard(
      'Publications per Year',
      SizedBox(
        height: 280,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxCount + 2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final year = sortedYears[group.x.toInt()];
                  return BarTooltipItem(
                    '$year\n${rod.toY.toInt()} papers',
                    GoogleFonts.interTight(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= sortedYears.length) {
                      return const SizedBox.shrink();
                    }
                    // Show every Nth label to avoid clutter
                    final step = (sortedYears.length / 8).ceil().clamp(1, 5);
                    if (idx % step != 0 && idx != sortedYears.length - 1) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${sortedYears[idx]}',
                          style: GoogleFonts.interTight(
                              fontSize: 10, color: AppTheme.textTertiary)),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    if (value == value.roundToDouble() && value >= 0) {
                      return Text('${value.toInt()}',
                          style: GoogleFonts.interTight(
                              fontSize: 10, color: AppTheme.textTertiary));
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: max(1, (maxCount / 5).ceilToDouble()),
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.border,
                strokeWidth: 0.8,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(sortedYears.length, (i) {
              final year = sortedYears[i];
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: yearCounts[year]!.toDouble(),
                    color: AppTheme.primary,
                    width: max(6, min(24, 300 / sortedYears.length)),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxCount + 2,
                      color: AppTheme.primary.withOpacity(0.04),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // --- Most Used Algorithms / Methods ---
  Widget _buildMethodologyChart(List<ResearchPaper> papers) {
    final methodCounts = <String, int>{};
    for (final p in papers) {
      if (p.methodology.isNotEmpty) {
        final method = p.methodology.trim();
        methodCounts[method] = (methodCounts[method] ?? 0) + 1;
      }
    }

    if (methodCounts.isEmpty) {
      return _chartCard('Most Used Algorithms / Methods', _noDataWidget());
    }

    // Sort by count descending, take top 10
    final sorted = methodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(10).toList();
    final maxVal = top.first.value.toDouble();

    final colors = [
      AppTheme.primary,
      AppTheme.info,
      AppTheme.success,
      AppTheme.warning,
      const Color(0xFF2D7A8A),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
      const Color(0xFF06B6D4),
      const Color(0xFF84CC16),
    ];

    return _chartCard(
      'Most Used Algorithms / Methods',
      SizedBox(
        height: 280,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal + 1,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final entry = top[group.x.toInt()];
                  return BarTooltipItem(
                    '${entry.key}\n${entry.value} papers',
                    GoogleFonts.interTight(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= top.length) {
                      return const SizedBox.shrink();
                    }
                    final label = top[idx].key.length > 12
                        ? '${top[idx].key.substring(0, 12)}...'
                        : top[idx].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Text(label,
                            style: GoogleFonts.interTight(
                                fontSize: 9, color: AppTheme.textTertiary)),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    if (value == value.roundToDouble() && value >= 0) {
                      return Text('${value.toInt()}',
                          style: GoogleFonts.interTight(
                              fontSize: 10, color: AppTheme.textTertiary));
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.border,
                strokeWidth: 0.8,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(top.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: top[i].value.toDouble(),
                    color: colors[i % colors.length],
                    width: max(10, min(28, 280 / top.length)),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // --- Keyword Frequency Analysis ---
  Widget _buildKeywordFrequency(List<ResearchPaper> papers) {
    final kwCounts = <String, int>{};
    for (final p in papers) {
      for (final kw in p.keywords) {
        final normalized = kw.trim().toLowerCase();
        if (normalized.isNotEmpty) {
          kwCounts[normalized] = (kwCounts[normalized] ?? 0) + 1;
        }
      }
    }

    if (kwCounts.isEmpty) {
      return _chartCard('Keyword Frequency Analysis', _noDataWidget());
    }

    final sorted = kwCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(12).toList();
    final maxVal = top.first.value.toDouble();

    return _chartCard(
      'Keyword Frequency Analysis',
      SizedBox(
        height: 280,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal + 1,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final entry = top[group.x.toInt()];
                  return BarTooltipItem(
                    '${entry.key}\n${entry.value}',
                    GoogleFonts.interTight(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= top.length) {
                      return const SizedBox.shrink();
                    }
                    final label = top[idx].key.length > 10
                        ? '${top[idx].key.substring(0, 10)}...'
                        : top[idx].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Text(label,
                            style: GoogleFonts.interTight(
                                fontSize: 9, color: AppTheme.textTertiary)),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    if (value == value.roundToDouble() && value >= 0) {
                      return Text('${value.toInt()}',
                          style: GoogleFonts.interTight(
                              fontSize: 10, color: AppTheme.textTertiary));
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.border,
                strokeWidth: 0.8,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(top.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: top[i].value.toDouble(),
                    color: AppTheme.warning,
                    width: max(8, min(22, 260 / top.length)),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // --- Country-wise Research Contribution ---
  Widget _buildCountryContribution(List<ResearchPaper> papers) {
    final countryCounts = <String, int>{};
    for (final p in papers) {
      if (p.country != null && p.country!.trim().isNotEmpty) {
        final c = p.country!.trim();
        countryCounts[c] = (countryCounts[c] ?? 0) + 1;
      }
    }

    if (countryCounts.isEmpty) {
      return _chartCard('Country-wise Research Contribution', _noDataWidget());
    }

    final sorted = countryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(10).toList();
    final total = top.fold<int>(0, (s, e) => s + e.value);

    final pieColors = [
      AppTheme.primary,
      AppTheme.info,
      AppTheme.success,
      AppTheme.warning,
      const Color(0xFF2D7A8A),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
      const Color(0xFF06B6D4),
      const Color(0xFF84CC16),
    ];

    return _chartCard(
      'Country-wise Research Contribution',
      SizedBox(
        height: 280,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: List.generate(top.length, (i) {
                    final pct = (top[i].value / total * 100);
                    return PieChartSectionData(
                      color: pieColors[i % pieColors.length],
                      value: top[i].value.toDouble(),
                      title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                      titleStyle: GoogleFonts.interTight(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      radius: 50,
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(top.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: pieColors[i % pieColors.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${top[i].key} (${top[i].value})',
                            style: GoogleFonts.interTight(
                                fontSize: 11, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Chart card container ---
  Widget _chartCard(String title, Widget child) {
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
              Text(title.toUpperCase(),
                  style: AppTheme.labelSmall().copyWith(color: AppTheme.primary)),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _noDataWidget() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 24, color: AppTheme.textTertiary),
            const SizedBox(height: 8),
            Text('Not enough data',
                style: GoogleFonts.interTight(
                    fontSize: 12, color: AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }
}
