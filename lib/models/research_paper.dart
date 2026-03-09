import 'dart:convert';

/// PRISMA screening stages
enum PrismaStage {
  identified,
  screened,
  eligible,
  included,
  excluded,
}

/// Research paper data model with all required fields
class ResearchPaper {
  final String id;
  String title;
  String authors;
  int? year;
  List<String> keywords;
  String abstract_;
  String methodology;
  String results;
  String? country;
  String? url;
  String? source; // journal / repository name
  String? topic; // search/review topic for grouping
  PrismaStage prismaStage;
  String? exclusionReason;

  ResearchPaper({
    required this.id,
    required this.title,
    required this.authors,
    this.year,
    this.keywords = const [],
    this.abstract_ = '',
    this.methodology = '',
    this.results = '',
    this.country,
    this.url,
    this.source,
    this.topic,
    this.prismaStage = PrismaStage.identified,
    this.exclusionReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors,
        'year': year,
        'keywords': keywords,
        'abstract': abstract_,
        'methodology': methodology,
        'results': results,
        'country': country,
        'url': url,
        'source': source,
        'topic': topic,
        'prismaStage': prismaStage.index,
        'exclusionReason': exclusionReason,
      };

  factory ResearchPaper.fromJson(Map<String, dynamic> json) {
    return ResearchPaper(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? '',
      authors: json['authors']?.toString() ?? '',
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? ''),
      keywords: (json['keywords'] is List)
          ? (json['keywords'] as List).map((e) => e.toString()).toList()
          : (json['keywords']?.toString() ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      abstract_: json['abstract']?.toString() ?? '',
      methodology: json['methodology']?.toString() ?? '',
      results: json['results']?.toString() ?? '',
      country: json['country']?.toString(),
      url: json['url']?.toString(),
      source: json['source']?.toString(),
      topic: json['topic']?.toString(),
      prismaStage: PrismaStage.values.elementAtOrNull(json['prismaStage'] is int ? json['prismaStage'] : 0) ?? PrismaStage.identified,
      exclusionReason: json['exclusionReason']?.toString(),
    );
  }

  /// Create from OpenAlex search result map (as used in main.dart)
  factory ResearchPaper.fromSearchResult(Map<String, String> result, {String? topic}) {
    final citation = result['citation'] ?? '';
    // Parse authors from citation: "Author1, Author2 (Year). Title. Venue."
    String authors = '';
    String title = '';
    int? year;

    final yearMatch = RegExp(r'\((\d{4})\)').firstMatch(citation);
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(1) ?? '');
      authors = citation.substring(0, yearMatch.start).trim();
      if (authors.endsWith(',')) authors = authors.substring(0, authors.length - 1).trim();
      final afterYear = citation.substring(yearMatch.end).trim();
      if (afterYear.startsWith('.')) {
        final rest = afterYear.substring(1).trim();
        final dotIdx = rest.indexOf('.');
        title = dotIdx > 0 ? rest.substring(0, dotIdx).trim() : rest;
      }
    } else {
      title = citation;
    }

    return ResearchPaper(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.isNotEmpty ? title : citation,
      authors: authors,
      year: year,
      methodology: result['methodology'] ?? '',
      results: result['key_outcome'] ?? '',
      url: result['url'],
      topic: topic,
    );
  }
}

/// PRISMA flow statistics computed from a list of papers
class PrismaFlowStats {
  final int identified;
  final int duplicatesRemoved;
  final int screened;
  final int excluded;
  final int fullTextAssessed;
  final int included;

  const PrismaFlowStats({
    required this.identified,
    required this.duplicatesRemoved,
    required this.screened,
    required this.excluded,
    required this.fullTextAssessed,
    required this.included,
  });

  factory PrismaFlowStats.fromPapers(List<ResearchPaper> papers) {
    final identified = papers.length;
    // Count by stage
    int screenedCount = 0;
    int eligibleCount = 0;
    int includedCount = 0;
    int excludedCount = 0;

    for (final p in papers) {
      switch (p.prismaStage) {
        case PrismaStage.screened:
          screenedCount++;
          break;
        case PrismaStage.eligible:
          eligibleCount++;
          break;
        case PrismaStage.included:
          includedCount++;
          break;
        case PrismaStage.excluded:
          excludedCount++;
          break;
        case PrismaStage.identified:
          break;
      }
    }

    // Papers that passed through screening = screened + eligible + included
    final passedScreening = screenedCount + eligibleCount + includedCount;

    return PrismaFlowStats(
      identified: identified,
      duplicatesRemoved: 0,
      screened: passedScreening + excludedCount,
      excluded: excludedCount,
      fullTextAssessed: eligibleCount + includedCount,
      included: includedCount,
    );
  }
}

/// Encode a list of papers to JSON string
String encodePapers(List<ResearchPaper> papers) {
  return jsonEncode(papers.map((p) => p.toJson()).toList());
}

/// Decode papers from JSON string
List<ResearchPaper> decodePapers(String json) {
  try {
    final list = jsonDecode(json);
    if (list is List) {
      return list.map((e) => ResearchPaper.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}
  return [];
}
