import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../widgets/car_card.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../widgets/part_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;

  List<String> _recentSearches = [];
  static const String _searchHistoryKey = 'gear_up_recent_searches';
  static const int _maxRecentSearches = 10;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        final cubit = context.read<MarketCubit>();
        if (!cubit.isSearchingMore && cubit.searchResults.isNotEmpty) {
          cubit.searchSpecificCar(_searchController.text, isLoadMore: true);
        }
      }
    });
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList(_searchHistoryKey) ?? [];
    });
  }

  Future<void> _saveSearchTerm(String term) async {
    final text = term.trim();
    if (text.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_searchHistoryKey) ?? [];

    history.remove(text);
    history.insert(0, text);

    if (history.length > _maxRecentSearches) {
      history = history.sublist(0, _maxRecentSearches);
    }

    await prefs.setStringList(_searchHistoryKey, history);
    setState(() {
      _recentSearches = history;
    });
  }

  Future<void> _deleteSearchTerm(String term) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_searchHistoryKey) ?? [];

    history.remove(term);
    await prefs.setStringList(_searchHistoryKey, history);

    setState(() {
      _recentSearches = history;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: screenBgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      context.read<MarketCubit>().clearSearch();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161E27) : Colors.transparent,
                        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.arrow_back, size: 22, color: isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Container(
                      height: 50,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161E27) : Colors.white,
                        border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                        onSubmitted: (value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          if (value.trim().isNotEmpty) {
                            _saveSearchTerm(value);
                            context.read<MarketCubit>().searchSpecificCar(value.trim());
                          }
                        },
                        onChanged: (value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();

                          if (value.isEmpty) {
                            context.read<MarketCubit>().clearSearch();
                            return;
                          }

                          _debounce = Timer(const Duration(milliseconds: 1500), () {
                            if (value.trim().isNotEmpty) {
                              _saveSearchTerm(value.trim());
                              context.read<MarketCubit>().searchSpecificCar(value.trim());
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: AppLang.tr(context, 'search_cars') ?? 'بحث...',
                          hintStyle: TextStyle(color: AppColors.textHint.withOpacity(0.8), fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 20),
                          // 🔥 السحر هنا: زرار الـ (X) بيظهر ويختفي بذكاء من غير ما يرندر الشاشة كلها 🔥
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, value, child) {
                              return value.text.isNotEmpty
                                  ? IconButton(
                                icon: const Icon(Icons.close, color: AppColors.textHint, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<MarketCubit>().clearSearch();
                                  FocusScope.of(context).unfocus(); // نزل الكيبورد لو داس X
                                },
                              )
                                  : const SizedBox.shrink();
                            },
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: BlocBuilder<MarketCubit, MarketState>(
                builder: (context, state) {
                  final cubit = context.read<MarketCubit>();

                  if (state is SearchCarsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (state is SearchCarsError) {
                    // 🔥 حماية الترجمة (V2) 🔥
                    return Center(
                      child: Text(
                          AppLang.tr(context, state.error) ?? state.error,
                          style: const TextStyle(color: AppColors.textHint, fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    );
                  }

                  if (cubit.searchResults.isNotEmpty) {
                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      itemCount: cubit.searchResults.length + (state is SearchCarsLoadingMore ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        if (index == cubit.searchResults.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                          );
                        }
                        final currentItem = cubit.searchResults[index];

                        if (currentItem.itemType == 'type_spare_part') {
                          return PartCard(partItem: currentItem, isPromoted: false);
                        } else {
                          return CarCard(car: currentItem, isPromoted: false);
                        }
                      },
                    );
                  }

                  if (_recentSearches.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.manage_search_rounded, size: 70, color: AppColors.textHint.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            AppLang.tr(context, 'start_searching') ?? 'ابدأ البحث الآن',
                            style: const TextStyle(color: AppColors.textHint, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.history, size: 16, color: AppColors.textHint),
                            const SizedBox(width: 8),
                            Text(
                              AppLang.tr(context, 'recent_searches') ?? 'عمليات البحث الأخيرة',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _recentSearches.length,
                          itemBuilder: (context, index) {
                            final term = _recentSearches[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                              leading: const Icon(Icons.search, color: AppColors.textHint, size: 20),
                              title: Text(term, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
                              trailing: _PremiumDeleteButton(
                                onTap: () => _deleteSearchTerm(term),
                              ),
                              onTap: () {
                                _searchController.text = term;
                                _saveSearchTerm(term);
                                context.read<MarketCubit>().searchSpecificCar(term);
                                FocusScope.of(context).unfocus();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumDeleteButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PremiumDeleteButton({required this.onTap});

  @override
  State<_PremiumDeleteButton> createState() => _PremiumDeleteButtonState();
}

class _PremiumDeleteButtonState extends State<_PremiumDeleteButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _isPressed ? Colors.redAccent.withOpacity(0.9) : Colors.redAccent.withOpacity(0.1),
          shape: BoxShape.circle,
          boxShadow: _isPressed
              ? [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
              : [],
        ),
        child: Icon(
            Icons.close_rounded,
            color: _isPressed ? Colors.white : Colors.redAccent,
            size: 16
        ),
      ),
    );
  }
}