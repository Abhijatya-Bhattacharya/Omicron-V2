import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/research_paper.dart';

/// PRISMA Flow Summary screen showing step-by-step filtering of studies
class PrismaFlowScreen extends StatelessWidget {
  final List<ResearchPaper> papers;

  const PrismaFlowScreen({super.key, required this.papers});

  @override
  Widget build(BuildContext context) {
    // Compute detailed counts
    int identifiedCount = papers.length;
    int excludedCount =
        papers.where((p) => p.prismaStage == PrismaStage.excluded).length;
    int eligibleCount =
        papers.where((p) => p.prismaStage == PrismaStage.eligible).length;
    int includedCount =
        papers.where((p) => p.prismaStage == PrismaStage.included).length;
    int identifiedOnly =
        papers.where((p) => p.prismaStage == PrismaStage.identified).length;

    // For the flow, treat "screened" as those that passed beyond identification
    int totalPassedIdentification = identifiedCount - identifiedOnly;
    int totalAssessedFullText = eligibleCount + includedCount;
    int excludedAtScreening =
        excludedCount; // simplification — excluded at any point

    // Collect exclusion reasons
    final exclusionReasons = <String, int>{};
    for (final p in papers) {
      if (p.prismaStage == PrismaStage.excluded && p.exclusionReason != null) {
        final reason = p.exclusionReason!;
        exclusionReasons[reason] = (exclusionReasons[reason] ?? 0) + 1;
      }
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
                    Text('PRISMA Flow',
                        style: GoogleFonts.interTight(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),

                // Header
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRISMA Flow Summary',
                        style: AppTheme.displayMedium()),
                    const SizedBox(height: 4),
                    Text(
                        'Study selection process following PRISMA guidelines',
                        style: GoogleFonts.interTight(
                            fontSize: 14,
                            color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 24),
                Container(height: 1, color: AppTheme.divider),
                const SizedBox(height: 32),

                if (papers.isEmpty)
                  _buildEmptyState()
                else ...[
                  // Summary stats cards
                  _buildSummaryRow(identifiedCount, excludedCount,
                      totalAssessedFullText, includedCount),
                  const SizedBox(height: 32),

                  // PRISMA Flow Diagram
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                        child: Container(
                          width: 560,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppTheme.glassSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.glassBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text('PRISMA 2020 Flow Diagram',
                                  style: GoogleFonts.interTight(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary)),
                              const SizedBox(height: 24),

                              // IDENTIFICATION
                              _flowBox(
                                'IDENTIFICATION',
                                'Records identified through\ndatabase searching',
                                identifiedCount,
                                AppTheme.info,
                                Icons.search_rounded,
                              ),
                              _flowArrow(),

                              // Duplicates row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _flowBox(
                                      'SCREENING',
                                      'Records after duplicates\nremoved',
                                      identifiedCount,
                                      AppTheme.warning,
                                      Icons.filter_list_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _sideBox(
                                    'Duplicates removed',
                                    0,
                                    AppTheme.textTertiary,
                                  ),
                                ],
                              ),
                              _flowArrow(),

                              // Screened
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _flowBox(
                                      '',
                                      'Records screened',
                                      totalPassedIdentification +
                                          identifiedOnly,
                                      AppTheme.warning,
                                      Icons.visibility_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _sideBox(
                                    'Records excluded',
                                    excludedAtScreening,
                                    AppTheme.error,
                                  ),
                                ],
                              ),
                              _flowArrow(),

                              // Eligibility
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _flowBox(
                                      'ELIGIBILITY',
                                      'Full-text articles assessed\nfor eligibility',
                                      totalAssessedFullText,
                                      const Color(0xFF2D7A8A),
                                      Icons.check_circle_outline,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _sideBox(
                                    'Full-text excluded',
                                    eligibleCount, // eligible but not yet included
                                    AppTheme.error,
                                  ),
                                ],
                              ),
                              _flowArrow(),

                              // Included
                              _flowBox(
                                'INCLUDED',
                                'Studies included in\nqualitative synthesis',
                                includedCount,
                                AppTheme.success,
                                Icons.done_all_rounded,
                                highlight: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Exclusion reasons breakdown
                  if (exclusionReasons.isNotEmpty) ...[
                    Text('EXCLUSION REASONS',
                        style: AppTheme.labelSmall()
                            .copyWith(color: AppTheme.primary)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.glassSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.glassBorder),
                          ),
                          child: Column(
                            children: exclusionReasons.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppTheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(e.key,
                                          style: GoogleFonts.interTight(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorLight,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text('${e.value}',
                                          style: GoogleFonts.interTight(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.error)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
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
            child: Icon(Icons.account_tree_outlined,
                size: 40, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 20),
          Text('No Papers in Database', style: AppTheme.titleMedium()),
          const SizedBox(height: 8),
          Text(
              'Add papers to the Research Database\nto see the PRISMA flow summary.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium()),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
      int identified, int excluded, int assessed, int included) {
    return Row(
      children: [
        Expanded(
            child: _summaryCard(
                'Records Identified', identified, AppTheme.info)),
        const SizedBox(width: 16),
        Expanded(
            child: _summaryCard(
                'Records Excluded', excluded, AppTheme.error)),
        const SizedBox(width: 16),
        Expanded(
            child: _summaryCard(
                'Full-text Assessed', assessed, const Color(0xFF2D7A8A))),
        const SizedBox(width: 16),
        Expanded(
            child: _summaryCard(
                'Final Included', included, AppTheme.success)),
      ],
    );
  }

  Widget _summaryCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text('$count',
              style: GoogleFonts.interTight(
                  fontSize: 28, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.interTight(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _flowBox(String phase, String description, int count, Color color,
      IconData icon,
      {bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: highlight ? color : color.withOpacity(0.4), width: highlight ? 2 : 1),
        boxShadow: highlight
            ? [
                BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (phase.isNotEmpty)
                  Text(phase,
                      style: GoogleFonts.interTight(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 1.0)),
                Text(description,
                    style: GoogleFonts.interTight(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('n = $count',
                style: GoogleFonts.interTight(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ],
      ),
    );
  }

  Widget _sideBox(String label, int count, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.interTight(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('(n = $count)',
              style: GoogleFonts.interTight(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _flowArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Icon(Icons.arrow_downward_rounded,
          size: 22, color: AppTheme.textTertiary),
    );
  }
}
