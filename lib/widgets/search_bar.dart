import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../services/api_service.dart';

class SearchBar extends StatefulWidget {
  final Function(LatLng location, String name) onLocationSelected;
  final String? hintText;

  const SearchBar({
    super.key,
    required this.onLocationSelected,
    this.hintText,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final ApiService _apiService;
  late final AnimationController _animationController;
  Animation<double>? _scaleAnimation;
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _showResults = false;
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    
    // Animation controller for search bar
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _showResults = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showResults = true;
    });

    try {
      final results = await _apiService.searchLocation(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
        
        if (_showResults) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Search failed: ${e.toString()}'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Show/hide results based on input
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    
    // Create new timer for debouncing (faster response)
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _controller.text == value) {
        _searchLocation(value);
      }
    });
  }

  void _selectLocation(Map<String, dynamic> location) {
    final latLng = LatLng(location['lat'], location['lon']);
    final name = location['display_name'];
    
    // Extract a shorter, cleaner name
    String displayName = name;
    if (name.contains(',')) {
      final parts = name.split(',');
      displayName = parts.take(2).join(',').trim();
    }
    
    _controller.text = displayName;
    _focusNode.unfocus();
    setState(() {
      _showResults = false;
      _searchResults = [];
    });
    
    widget.onLocationSelected(latLng, name);
  }

  void _clearSearch() {
    _controller.clear();
    _debounceTimer?.cancel();
    setState(() {
      _searchResults = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use animation if available, otherwise use identity
    final scaleAnimation = _scaleAnimation ?? AlwaysStoppedAnimation<double>(1.0);
    
    return ScaleTransition(
      scale: scaleAnimation,
      child: Column(
        children: [
          _buildSearchField(),
          if (_showResults) _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final bool hasFocus = _focusNode.hasFocus;
    
    return Container(
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
          width: hasFocus ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: hasFocus ? 0.15 : 0.08),
            blurRadius: hasFocus ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? '🔍 Search location & check safety...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 4, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: hasFocus ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
              size: 24,
            ),
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 20,
                        height: 20,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                        ),
                      ),
                    IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear_rounded),
                      color: const Color(0xFF64748B),
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 350),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _isLoading
            ? const _LoadingWidget()
            : _searchResults.isEmpty
                ? _NoResultsWidget(query: _controller.text)
                : _SearchResultsList(
                    results: _searchResults.take(6).toList(),
                    onLocationSelected: _selectLocation,
                  ),
      ),
    );
  }
}

// Modern loading widget
class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Searching locations...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Modern no results widget
class _NoResultsWidget extends StatelessWidget {
  final String query;
  
  const _NoResultsWidget({required this.query});

  @override
  Widget build(BuildContext context) {
    final isQueryTooShort = query.trim().length < 3;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isQueryTooShort ? Icons.search_off : Icons.location_off,
            size: 48,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            isQueryTooShort ? 'Type at least 3 characters' : 'No locations found',
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isQueryTooShort
                ? 'Enter more characters to search'
                : 'Try a different search term',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Modern results list widget
class _SearchResultsList extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Function(Map<String, dynamic>) onLocationSelected;

  const _SearchResultsList({
    required this.results,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 56,
        endIndent: 16,
        color: Color(0xFFE2E8F0),
      ),
      itemBuilder: (context, index) {
        final result = results[index];
        return _SearchResultTile(
          result: result,
          onTap: () => onLocationSelected(result),
          isFirst: index == 0,
          isLast: index == results.length - 1,
        );
      },
    );
  }
}

// Modern result tile widget with enhanced design
class _SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _SearchResultTile({
    required this.result,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final String fullName = result['display_name'] ?? '';
    final parts = fullName.split(',');
    final String mainName = parts.isNotEmpty ? parts[0].trim() : fullName;
    final String subName = parts.length > 1 
        ? parts.skip(1).take(2).join(', ').trim() 
        : '';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Location icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Location details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        height: 1.3,
                      ),
                    ),
                    if (subName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Arrow icon
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simplified search delegate for better performance
class LocationSearchDelegate extends SearchDelegate<LatLng?> {
  late final ApiService _apiService;

  LocationSearchDelegate() {
    _apiService = ApiService();
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Enter a location to search'),
      );
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _apiService.searchLocation(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(
            child: Text('No results found'),
          );
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(
                result['display_name'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                final latLng = LatLng(result['lat'], result['lon']);
                close(context, latLng);
              },
            );
          },
        );
      },
    );
  }
}
