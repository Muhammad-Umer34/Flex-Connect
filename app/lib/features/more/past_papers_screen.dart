import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/past_paper.dart';

class PastPapersScreen extends StatefulWidget {
  const PastPapersScreen({super.key});

  @override
  State<PastPapersScreen> createState() => _PastPapersScreenState();
}

class _PastPapersScreenState extends State<PastPapersScreen> {
  Map<String, List<PastPaper>> _papersBySubject = {};
  List<String> _uniqueSubjects = [];
  List<String> _filteredSubjects = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  static const Color _accent = Color(0xFF2563EB); // Royal Blue

  Color get _ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get _containerBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get _containerBorder => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
  Color get _cardBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white;
  Color get _inputBorder => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _headerSub => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A);
  Color get _iconBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF);

  @override
  void initState() {
    super.initState();
    _loadPapersData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPapersData() async {
    final papers = await PastPaper.loadFromAssets();
    
    // Pre-group papers by subject
    final grouped = <String, List<PastPaper>>{};
    for (final paper in papers) {
      (grouped[paper.subject] ??= []).add(paper);
    }

    // Extract unique subjects sorted alphabetically
    final subjects = grouped.keys.toList()..sort();

    if (mounted) {
      setState(() {
        _papersBySubject = grouped;
        _uniqueSubjects = subjects;
        _filteredSubjects = subjects;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSubjects = _uniqueSubjects
          .where((subject) => subject.toLowerCase().contains(query))
          .toList();
    });
  }

  Widget _buildPapersHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _inputBorder, width: 1),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: _ink,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accent.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(
                Icons.library_books_outlined,
                color: _accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Past Papers & Resources',
              style: TextStyle(
                color: _headerSub,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Past Papers',
          style: TextStyle(
            color: _ink,
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'FAST DRIVE RESOURCES',
          style: TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: _accent),
                    const SizedBox(height: 16),
                    Text(
                      'Loading drive archives...',
                      style: TextStyle(color: _muted, fontSize: 14),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPapersHeader(context),
                    const SizedBox(height: 48),
                    _buildTitleSection(context),
                    const SizedBox(height: 36),
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: _ink),
                      decoration: InputDecoration(
                        hintText: 'Search subjects...',
                        hintStyle: TextStyle(color: _muted, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_outlined, color: _accent),
                        fillColor: _cardBg,
                        filled: true,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: _muted),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _filteredSubjects.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.find_in_page_outlined,
                                    size: 80,
                                    color: _muted.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No subjects found',
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try checking spelling or use keywords',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredSubjects.length,
                            itemBuilder: (context, index) {
                              final subject = _filteredSubjects[index];
                              final subjectPapers = _papersBySubject[subject] ?? const [];
                              final count = subjectPapers.length;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SubjectPapersScreen(
                                          subjectName: subject,
                                          papers: subjectPapers,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _containerBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _containerBorder, width: 1),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _iconBg,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.folder_open_rounded,
                                            color: _accent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                subject,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: _ink,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$count files available',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20,
                                          color: _muted,
                                        ),
                                      ],
                                    ),
                                  ),
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

class SubjectPapersScreen extends StatefulWidget {
  final String subjectName;
  final List<PastPaper> papers;

  const SubjectPapersScreen({
    super.key,
    required this.subjectName,
    required this.papers,
  });

  @override
  State<SubjectPapersScreen> createState() => _SubjectPapersScreenState();
}

class _SubjectPapersScreenState extends State<SubjectPapersScreen> {
  final Set<String> _expandedCategories = {};
  final Map<String, List<PastPaper>> _groupedPapers = {};
  
  static const Color _accent = Color(0xFF2563EB); // Royal Blue

  Color get _ink => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _muted => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get _containerBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get _containerBorder => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
  Color get _cardBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white;
  Color get _inputBorder => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _headerSub => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A);
  Color get _iconBg => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF);

  @override
  void initState() {
    super.initState();
    _groupAndFilterPapers();
  }

  void _groupAndFilterPapers() {
    _groupedPapers['Mid 1'] = [];
    _groupedPapers['Mid 2'] = [];
    _groupedPapers['Finals'] = [];
    _groupedPapers['Quizzes'] = [];
    _groupedPapers['Assignments'] = [];
    _groupedPapers['Slides'] = [];
    _groupedPapers['Other'] = [];

    for (final paper in widget.papers) {
      final pc = paper.category.trim().toLowerCase();
      if (pc == 'mid 1' || pc == 'mid1') {
        _groupedPapers['Mid 1']!.add(paper);
      } else if (pc == 'mid 2' || pc == 'mid2') {
        _groupedPapers['Mid 2']!.add(paper);
      } else if (pc == 'finals' || pc == 'final') {
        _groupedPapers['Finals']!.add(paper);
      } else if (pc == 'quizzes' || pc == 'quiz') {
        _groupedPapers['Quizzes']!.add(paper);
      } else if (pc == 'assignments' || pc == 'assignment') {
        _groupedPapers['Assignments']!.add(paper);
      } else if (pc == 'slides' || pc == 'slide' || pc == 'lecture' || pc == 'lectures') {
        _groupedPapers['Slides']!.add(paper);
      } else {
        _groupedPapers['Other']!.add(paper);
      }
    }

    // Remove empty categories so we don't render them
    _groupedPapers.removeWhere((key, list) => list.isEmpty);
  }

  Future<void> _openPaperLink(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  IconData _getFileIcon(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    } else if (name.endsWith('.ppt') || name.endsWith('.pptx')) {
      return Icons.slideshow_outlined;
    } else if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.description_outlined;
    } else if (name.endsWith('.xlsx') || name.endsWith('.xls') || name.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    } else {
      return Icons.insert_drive_file_outlined;
    }
  }

  Color _getFileIconColor(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.pdf')) {
      return const Color(0xFFEF4444); // Red
    } else if (name.endsWith('.ppt') || name.endsWith('.pptx')) {
      return const Color(0xFFF59E0B); // Amber
    } else if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return const Color(0xFF3B82F6); // Blue
    } else if (name.endsWith('.xlsx') || name.endsWith('.xls') || name.endsWith('.csv')) {
      return const Color(0xFF10B981); // Emerald
    } else {
      return const Color(0xFF6B7280); // Grey
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Mid 1':
        return Icons.looks_one_outlined;
      case 'Mid 2':
        return Icons.looks_two_outlined;
      case 'Finals':
        return Icons.assignment_turned_in_outlined;
      case 'Quizzes':
        return Icons.quiz_outlined;
      case 'Assignments':
        return Icons.task_outlined;
      case 'Slides':
        return Icons.slideshow_outlined;
      default:
        return Icons.folder_open_outlined;
    }
  }

  Widget _buildSubjectHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _inputBorder, width: 1),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: _ink,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accent.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(
                Icons.folder_shared_outlined,
                color: _accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Subject Resources',
              style: TextStyle(
                color: _headerSub,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resources',
          style: TextStyle(
            color: _ink,
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.subjectName.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesList = _groupedPapers.keys.toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubjectHeader(context),
              const SizedBox(height: 48),
              _buildTitleSection(context),
              const SizedBox(height: 36),
              
              categoriesList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: _muted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No resource files found for this subject.',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categoriesList.length,
                      itemBuilder: (context, index) {
                        final category = categoriesList[index];
                        final isExpanded = _expandedCategories.contains(category);
                        final papers = _groupedPapers[category] ?? const [];
                        final count = papers.length;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _containerBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _containerBorder, width: 1),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedCategories.remove(category);
                                    } else {
                                      _expandedCategories.add(category);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _iconBg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(category),
                                          color: _accent,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: _ink,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$count files available',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isExpanded ? Icons.expand_less : Icons.expand_more,
                                        color: _muted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isExpanded) ...[
                                Divider(color: _containerBorder, height: 1),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: papers.length,
                                  separatorBuilder: (context, idx) => Divider(color: _containerBorder, height: 1),
                                  itemBuilder: (context, idx) {
                                    final paper = papers[idx];
                                    final fileIcon = _getFileIcon(paper.fileName);
                                    final fileColor = _getFileIconColor(paper.fileName);

                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: Icon(fileIcon, color: fileColor),
                                      title: Text(
                                        paper.fileName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: _ink,
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.open_in_new_rounded,
                                        color: _accent,
                                        size: 18,
                                      ),
                                      onTap: () => _openPaperLink(paper.link),
                                    );
                                  },
                                ),
                              ],
                            ],
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
