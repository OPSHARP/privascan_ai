import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/document.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/document_classifier_service.dart';
import '../blocs/document_bloc.dart';
import 'scanner_screen.dart';
import 'document_workspace_screen.dart';
import 'pdf_preview_screen.dart';
import 'settings_screen.dart';
import '../widgets/home_features_grid.dart';

class DashboardScreen extends StatefulWidget {
  final bool embedded;

  const DashboardScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final bool _isGridView = true;
  bool _isSearchVisible = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    context.read<DocumentBloc>().add(LoadDocuments());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            backgroundColor: theme.scaffoldBackgroundColor.withValues(
              alpha: 0.85,
            ),
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 16,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
            title: const AnimatedPrivaScanTitle(),
            actions: _isSelectionMode
                ? [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedIds.clear();
                        });
                      },
                    ),
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '${_selectedIds.length} selected',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    if (_selectedIds.length >= 2)
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.doc_on_doc_fill,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () => _mergeSelectedDocuments(context),
                        tooltip:
                            'Merge ${_selectedIds.length} into Single PDF',
                      ),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.trash,
                        color: CupertinoColors.destructiveRed,
                      ),
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () {
                              _confirmMultiDelete(context);
                            },
                      tooltip: 'Move Selected to Trash',
                    ),
                  ]
                : [
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.search,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearchVisible = !_isSearchVisible;
                          if (!_isSearchVisible) {
                            _searchController.clear();
                            context.read<DocumentBloc>().add(LoadDocuments());
                            FocusScope.of(context).unfocus();
                          }
                        });
                      },
                      tooltip: 'Search',
                    ),
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.settings,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                      tooltip: 'Settings',
                    ),
                  ],
          ),
          if (_isSearchVisible)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CupertinoSearchTextField(
                      controller: _searchController,
                      backgroundColor: isDark
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFE5E5EA),
                      placeholder: 'Search name or scanned text (OCR)...',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      onChanged: (query) {
                        context.read<DocumentBloc>().add(SearchDocuments(query));
                      },
                      onSuffixTap: () {
                        _searchController.clear();
                        context.read<DocumentBloc>().add(LoadDocuments());
                        FocusScope.of(context).unfocus();
                      },
                    ),
                    BlocBuilder<DocumentBloc, DocumentState>(
                      builder: (context, state) {
                        if (state is DocumentLoaded && state.searchQuery.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.search,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Found ${state.filteredDocuments.length} document${state.filteredDocuments.length == 1 ? '' : 's'} matching "${state.searchQuery}"',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (!_isSearchVisible || _searchController.text.trim().isEmpty)
            const SliverToBoxAdapter(
              child: HomeFeaturesGrid(),
            ),
          BlocBuilder<DocumentBloc, DocumentState>(
            builder: (context, state) {
              final allDocs =
                  (state is DocumentLoaded) ? state.documents : <Document>[];
              final trashDocs =
                  (state is DocumentLoaded) ? state.trashDocuments : <Document>[];
              if (allDocs.isEmpty && trashDocs.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildCategoryFilterBar(
                    allDocs,
                    trashDocs,
                    theme,
                    isDark,
                  ),
                ),
              );
            },
          ),
          BlocBuilder<DocumentBloc, DocumentState>(
            builder: (context, state) {
              if (state is DocumentLoaded &&
                  _selectedCategory == 'trash' &&
                  state.trashDocuments.isNotEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.destructiveRed.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: CupertinoColors.destructiveRed.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.trash,
                          size: 18,
                          color: CupertinoColors.destructiveRed,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Trash auto-deletes items after 30 days.',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.destructiveRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          color: CupertinoColors.destructiveRed,
                          borderRadius: BorderRadius.circular(8),
                          onPressed: () => _confirmEmptyTrash(context),
                          child: const Text(
                            'Empty Trash',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            },
          ),
          BlocBuilder<DocumentBloc, DocumentState>(
            builder: (context, state) {
              if (state is DocumentLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }
              if (state is DocumentLoaded) {
                final isTrashView = _selectedCategory == 'trash';
                final documents = isTrashView
                    ? state.trashDocuments
                    : _applyCategoryFilter(state.filteredDocuments);
                final query = state.searchQuery;
                if (documents.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: _buildEmptyState(
                        theme,
                        searchQuery: query,
                        isTrash: isTrashView,
                      ),
                    ),
                  );
                }
                return _isGridView
                    ? _buildGridView(
                        documents,
                        theme,
                        searchQuery: query,
                        isTrash: isTrashView,
                      )
                    : _buildListView(
                        documents,
                        theme,
                        searchQuery: query,
                        isTrash: isTrashView,
                      );
              }
              if (state is DocumentError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_circle,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${state.message}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SliverFillRemaining(child: _buildEmptyState(theme));
            },
          ),
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 110),
          ), // Space for floating bottom nav bar
        ],
      ),
      bottomNavigationBar: widget.embedded ? null : const BannerAdWidget(),
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton(
              onPressed: () => _openScanner(context),
              child: const Icon(CupertinoIcons.camera),
            ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme, {
    String searchQuery = '',
    bool isTrash = false,
  }) {
    if (isTrash) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.trash,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              Text(
                'Trash is Empty',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Documents deleted from your dashboard stay in Trash for 30 days before being permanently wiped.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final isSearching = searchQuery.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? CupertinoIcons.search
                  : CupertinoIcons.doc_on_doc,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No Matching Documents' : 'No Documents',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'No documents matched "$searchQuery" in document name or scanned text (OCR).'
                  : 'Tap the camera button to scan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(
    List<Document> documents,
    ThemeData theme, {
    String searchQuery = '',
    bool isTrash = false,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => RepaintBoundary(
            child: _buildDocumentCard(
              documents[index],
              theme,
              searchQuery,
              isTrash,
            ),
          ),
          childCount: documents.length,
        ),
      ),
    );
  }

  Widget _buildListView(
    List<Document> documents,
    ThemeData theme, {
    String searchQuery = '',
    bool isTrash = false,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final isFirst = index == 0;
          final isLast = index == documents.length - 1;
          return RepaintBoundary(
            child: _buildDocumentListTile(
              documents[index],
              theme,
              isFirst,
              isLast,
              searchQuery,
              isTrash,
            ),
          );
        }, childCount: documents.length),
      ),
    );
  }

  Widget _buildDocumentCard(
    Document document,
    ThemeData theme, [
    String searchQuery = '',
    bool isTrash = false,
  ]) {
    final hasImage = document.imagePaths.isNotEmpty;
    final isSelected = _selectedIds.contains(document.id);
    final snippet = searchQuery.isNotEmpty
        ? document.getSearchSnippet(searchQuery)
        : null;

    return GestureDetector(
      onTap: () {
        if (isTrash) {
          _showTrashActionSheet(context, document);
          return;
        }
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(document.id);
              if (_selectedIds.isEmpty) {
                _isSelectionMode = false;
              }
            } else {
              _selectedIds.add(document.id);
            }
          });
        } else {
          _openDocument(document);
        }
      },
      onLongPress: () {
        if (isTrash) {
          _showTrashActionSheet(context, document);
          return;
        }
        HapticFeedback.mediumImpact();
        setState(() {
          _isSelectionMode = true;
          _selectedIds.add(document.id);
        });
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: CupertinoColors.activeBlue, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasImage)
                        Image.file(
                          File(document.imagePaths.first),
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                        )
                      else
                        Container(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                          child: Icon(
                            CupertinoIcons.doc,
                            size: 40,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildCategoryBadge(document, theme),
                      ),
                      if (document.isFavorite && !_isSelectionMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.star_fill,
                              color: Color(0xFFF59E0B),
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              document.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (!isTrash)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _showActionSheet(context, document),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  CupertinoIcons.ellipsis,
                                  size: 16,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (snippet != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.text_quote,
                              size: 11,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                snippet,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(document.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                isSelected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                color: isSelected ? CupertinoColors.activeBlue : Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentListTile(
    Document document,
    ThemeData theme,
    bool isFirst,
    bool isLast, [
    String searchQuery = '',
    bool isTrash = false,
  ]) {
    final hasImage = document.imagePaths.isNotEmpty;
    final isSelected = _selectedIds.contains(document.id);
    final snippet = searchQuery.isNotEmpty
        ? document.getSearchSnippet(searchQuery)
        : null;

    return GestureDetector(
      onTap: () {
        if (isTrash) {
          _showTrashActionSheet(context, document);
          return;
        }
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(document.id);
              if (_selectedIds.isEmpty) {
                _isSelectionMode = false;
              }
            } else {
              _selectedIds.add(document.id);
            }
          });
        } else {
          _openDocument(document);
        }
      },
      onLongPress: () {
        if (isTrash) {
          _showTrashActionSheet(context, document);
          return;
        }
        HapticFeedback.mediumImpact();
        setState(() {
          _isSelectionMode = true;
          _selectedIds.add(document.id);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue.withValues(alpha: 0.1)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(12) : Radius.zero,
            bottom: isLast ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        isSelected
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.circle,
                        color: isSelected
                            ? CupertinoColors.activeBlue
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                        size: 24,
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: hasImage
                          ? Image.file(
                              File(document.imagePaths.first),
                              fit: BoxFit.cover,
                              cacheWidth: 100,
                            )
                          : Container(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.05,
                              ),
                              child: Icon(
                                CupertinoIcons.doc,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                        ),
                        if (snippet != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.text_quote,
                                  size: 11,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: RichText(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    text: _buildHighlightedTextSpan(
                                      snippet,
                                      searchQuery,
                                      theme,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                _formatDate(document.createdAt),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildCategoryBadge(document, theme),
                              if (document.isFavorite) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  CupertinoIcons.star_fill,
                                  color: Color(0xFFF59E0B),
                                  size: 13,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!_isSelectionMode)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => isTrash
                          ? _showTrashActionSheet(context, document)
                          : _showActionSheet(context, document),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          CupertinoIcons.ellipsis_vertical,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.only(left: 80),
                child: Divider(height: 1, color: theme.dividerTheme.color),
              ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildHighlightedTextSpan(
    String text,
    String query,
    ThemeData theme,
  ) {
    if (query.trim().isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase().trim();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(
            text: text.substring(start),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + lowerQuery.length),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ));

      start = index + lowerQuery.length;
    }

    return TextSpan(children: spans);
  }

  void _showActionSheet(BuildContext context, Document document) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(document.name),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Open'),
            onPressed: () {
              Navigator.pop(context);
              _openDocument(document);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Select Document'),
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.lightImpact();
              setState(() {
                _isSelectionMode = true;
                _selectedIds.add(document.id);
              });
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              document.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            ),
            onPressed: () {
              Navigator.pop(context);
              final updated = document.copyWith(
                isFavorite: !document.isFavorite,
                updatedAt: DateTime.now(),
              );
              context.read<DocumentBloc>().add(UpdateDocument(updated));
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Change Category'),
            onPressed: () {
              Navigator.pop(context);
              _showCategoryPicker(document);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(context, document);
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  List<Document> _applyCategoryFilter(List<Document> docs) {
    if (_selectedCategory == 'all') return docs;
    if (_selectedCategory == 'favorites') {
      return docs.where((d) => d.isFavorite).toList();
    }
    if (_selectedCategory == DocumentClassifierService.other.id) {
      return docs
          .where(
            (d) =>
                d.primaryCategory == null ||
                d.primaryCategory == DocumentClassifierService.other.id,
          )
          .toList();
    }
    return docs.where((d) => d.tags.contains(_selectedCategory)).toList();
  }

  Widget _buildCategoryBadge(Document document, ThemeData theme) {
    if (document.tags.contains(AppConstants.trashTag)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: CupertinoColors.destructiveRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: CupertinoColors.destructiveRed.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.trash,
              size: 10,
              color: CupertinoColors.destructiveRed,
            ),
            SizedBox(width: 4),
            Text(
              'In Trash',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.destructiveRed,
              ),
            ),
          ],
        ),
      );
    }
    final catId = document.primaryCategory;
    final category = DocumentClassifierService.getCategoryById(catId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: category.color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 10, color: category.color),
          const SizedBox(width: 4),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterBar(
    List<Document> allDocs,
    List<Document> trashDocs,
    ThemeData theme,
    bool isDark,
  ) {
    final filterOptions = [
      (
        id: 'all',
        label: 'All',
        icon: CupertinoIcons.square_grid_2x2,
        color: theme.colorScheme.primary,
      ),
      (
        id: 'favorites',
        label: 'Favorites',
        icon: CupertinoIcons.star_fill,
        color: const Color(0xFFF59E0B),
      ),
      (
        id: DocumentClassifierService.receipts.id,
        label: 'Receipts',
        icon: DocumentClassifierService.receipts.icon,
        color: DocumentClassifierService.receipts.color,
      ),
      (
        id: DocumentClassifierService.ids.id,
        label: 'IDs & Cards',
        icon: DocumentClassifierService.ids.icon,
        color: DocumentClassifierService.ids.color,
      ),
      (
        id: DocumentClassifierService.medical.id,
        label: 'Medical',
        icon: DocumentClassifierService.medical.icon,
        color: DocumentClassifierService.medical.color,
      ),
      (
        id: DocumentClassifierService.legal.id,
        label: 'Legal',
        icon: DocumentClassifierService.legal.icon,
        color: DocumentClassifierService.legal.color,
      ),
      (
        id: DocumentClassifierService.notes.id,
        label: 'Notes',
        icon: DocumentClassifierService.notes.icon,
        color: DocumentClassifierService.notes.color,
      ),
      (
        id: DocumentClassifierService.other.id,
        label: 'Other',
        icon: DocumentClassifierService.other.icon,
        color: DocumentClassifierService.other.color,
      ),
      if (trashDocs.isNotEmpty)
        (
          id: 'trash',
          label: 'Trash',
          icon: CupertinoIcons.trash,
          color: CupertinoColors.destructiveRed,
        ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filterOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opt = filterOptions[index];
          final isSelected = _selectedCategory == opt.id;

          int count = 0;
          if (opt.id == 'all') {
            count = allDocs.length;
          } else if (opt.id == 'trash') {
            count = trashDocs.length;
          } else if (opt.id == 'favorites') {
            count = allDocs.where((d) => d.isFavorite).length;
          } else if (opt.id == DocumentClassifierService.other.id) {
            count =
                allDocs
                    .where(
                      (d) =>
                          d.primaryCategory == null ||
                          d.primaryCategory == opt.id,
                    )
                    .length;
          } else {
            count = allDocs.where((d) => d.tags.contains(opt.id)).length;
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = opt.id;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? opt.color
                    : (isDark
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFE5E5EA)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? opt.color : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt.icon,
                    size: 13,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : theme.colorScheme.onSurface.withValues(
                              alpha: 0.1,
                            ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCategoryPicker(Document document) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Assign Category to "${document.name}"'),
        message: const Text('Smart offline folders organize your documents seamlessly'),
        actions: DocumentClassifierService.allCategories.map((category) {
          final isCurrent = document.primaryCategory == category.id;
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              final newTags = document.tags
                  .where((t) => !t.startsWith('category_'))
                  .toList()..add(category.id);
              final updated = document.copyWith(
                tags: newTags,
                updatedAt: DateTime.now(),
              );
              context.read<DocumentBloc>().add(UpdateDocument(updated));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, size: 18, color: category.color),
                const SizedBox(width: 8),
                Text(
                  category.name,
                  style: TextStyle(
                    color: isCurrent ? category.color : null,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Icon(CupertinoIcons.checkmark, size: 16, color: category.color),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Document document) {
    context.read<DocumentBloc>().add(MoveToTrash(document.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Moved "${document.name}" to Trash (auto-deleted in 30 days)',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            context.read<DocumentBloc>().add(RestoreDocument(document.id));
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _confirmMultiDelete(BuildContext context) {
    final count = _selectedIds.length;
    final idsToDelete = List<String>.from(_selectedIds);
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    context.read<DocumentBloc>().add(MoveMultipleToTrash(idsToDelete));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Moved $count document${count > 1 ? 's' : ''} to Trash',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            for (final id in idsToDelete) {
              context.read<DocumentBloc>().add(RestoreDocument(id));
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _mergeSelectedDocuments(BuildContext context) {
    final state = context.read<DocumentBloc>().state;
    if (state is! DocumentLoaded) return;

    final selectedDocs = state.documents
        .where((d) => _selectedIds.contains(d.id))
        .toList();
    if (selectedDocs.length < 2) return;

    final mergedImagePaths = <String>[];
    final textBuffer = StringBuffer();

    for (final doc in selectedDocs) {
      mergedImagePaths.addAll(doc.imagePaths);
      if (doc.extractedText != null && doc.extractedText!.trim().isNotEmpty) {
        textBuffer.writeln('=== ${doc.name} ===');
        textBuffer.writeln(doc.extractedText!.trim());
        textBuffer.writeln();
      }
    }

    if (mergedImagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected documents have no scanned pages.'),
        ),
      );
      return;
    }

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => PdfPreviewScreen(
          documentName: 'Merged Document (${selectedDocs.length} Docs)',
          imagePaths: mergedImagePaths,
          extractedText:
              textBuffer.isNotEmpty ? textBuffer.toString().trim() : null,
        ),
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text(
          'All documents in the trash will be permanently deleted from this device. This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Empty Trash'),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<DocumentBloc>().add(EmptyTrash());
              setState(() {
                _selectedCategory = 'all';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trash has been emptied.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTrashActionSheet(BuildContext context, Document document) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(document.name),
        message: const Text(
          'Item in Trash (permanently removed after 30 days)',
        ),
        actions: [
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.arrow_counterclockwise, size: 18),
                SizedBox(width: 8),
                Text('Restore Document'),
              ],
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<DocumentBloc>().add(RestoreDocument(document.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Restored "${document.name}"')),
              );
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.trash_fill, size: 18),
                SizedBox(width: 8),
                Text('Delete Permanently'),
              ],
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmPermanentDelete(context, document);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _confirmPermanentDelete(BuildContext context, Document document) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text(
          'Permanently delete "${document.name}" and all its scanned image files? This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete Forever'),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<DocumentBloc>().add(DeleteDocument(document.id));
            },
          ),
        ],
      ),
    );
  }

  void _openScanner(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const ScannerScreen()),
    );
  }

  void _openDocument(Document document) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => DocumentWorkspaceScreen(document: document),
      ),
    );
  }
}

class AnimatedPrivaScanTitle extends StatefulWidget {
  const AnimatedPrivaScanTitle({super.key});

  @override
  State<AnimatedPrivaScanTitle> createState() => _AnimatedPrivaScanTitleState();
}

class _AnimatedPrivaScanTitleState extends State<AnimatedPrivaScanTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shimmerValue = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Glowing pulsing AI icon
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(
                      alpha: 0.3 + (math.sin(shimmerValue * 2 * math.pi).abs() * 0.3),
                    ),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.sparkles,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
            // Shimmering Gradient Animated Title Text
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: isDark
                      ? const [
                          Color(0xFF60A5FA),
                          Color(0xFFA78BFA),
                          Color(0xFF38BDF8),
                          Color(0xFF60A5FA),
                        ]
                      : const [
                          Color(0xFF1D4ED8),
                          Color(0xFF6D28D9),
                          Color(0xFF0284C7),
                          Color(0xFF1D4ED8),
                        ],
                  stops: [
                    (shimmerValue - 0.4).clamp(0.0, 1.0),
                    (shimmerValue - 0.1).clamp(0.0, 1.0),
                    (shimmerValue + 0.2).clamp(0.0, 1.0),
                    (shimmerValue + 0.5).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds);
              },
              child: const Text(
                'PrivaScan AI',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  letterSpacing: -0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

