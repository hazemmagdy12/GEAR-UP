import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../widgets/ai_chat_bottom_sheet.dart';
import '../widgets/filters_bottom_sheet.dart';
import '../widgets/part_card.dart';
import 'car_details_screen.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../marketplace/models/car_model.dart';
import '../../marketplace/models/news_model.dart';

class ViewAllCarsScreen extends StatefulWidget {
  final String title;
  const ViewAllCarsScreen({super.key, required this.title});

  @override
  State<ViewAllCarsScreen> createState() => _ViewAllCarsScreenState();
}

class _ViewAllCarsScreenState extends State<ViewAllCarsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  String _searchQuery = "";
  Timer? _debounce;
  bool _isSearchFocused = false;
  bool _isDebouncing = false;

  List<CarModel> _currentList = [];
  bool _isListInitialized = false;
  bool _isLoadingMoreLocal = false;

  List<String> _selectedCompanies = [];
  String _selectedPriceSort = 'الافتراضي';

  final Map<String, String> _brandNormalizer = {
    'بي ام': 'BMW', 'بى ام': 'BMW', 'بي ام دبليو': 'BMW',
    'أودي': 'AUDI', 'اودي': 'AUDI', 'AUDI': 'AUDI',
    'مرسيدس': 'MERCEDES', 'MERCEDES-BENZ': 'MERCEDES',
    'تويوتا': 'TOYOTA', 'تايوتا': 'TOYOTA',
    'هيونداي': 'HYUNDAI', 'هونداي': 'HYUNDAI',
    'كيا': 'KIA', 'كيا موتورز': 'KIA',
    'نيسان': 'NISSAN', 'نيصان': 'NISSAN',
    'شيفروليه': 'CHEVROLET', 'شفروليه': 'CHEVROLET',
    'سكودا': 'SKODA', 'اسكودا': 'SKODA',
    'فولكس': 'VOLKSWAGEN', 'فولكس فاجن': 'VOLKSWAGEN', 'VW': 'VOLKSWAGEN',
    'رينو': 'RENAULT', 'رينوت': 'RENAULT',
    'بيجو': 'PEUGEOT', 'بيجوت': 'PEUGEOT',
    'مازدا': 'MAZDA', 'سيتروين': 'CITROEN', 'سيات': 'SEAT',
    'جيب': 'JEEP', 'فورد': 'FORD', 'فيات': 'FIAT'
  };

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      final cubit = context.read<MarketCubit>();
      _initializeList(cubit);
    });

    // 🔥 الـ Listener السحري للاسكرول اللانهائي (لوكال -> فايربيز -> API) 🔥
    _scrollController.addListener(() {
      if (_searchQuery.isNotEmpty) return; // بنقفل الانفينتي اسكرول وقت السيرش عشان الداتا متتدخلش في بعض

      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<CarModel>> _getSourceList(MarketCubit cubit) async {
    String translatedPromoted = AppLang.tr(context, 'promoted') ?? 'Promoted';
    String translatedPromotedParts = AppLang.tr(context, 'promoted_parts') ?? "قطع غيار ممولة";

    if (widget.title == translatedPromotedParts || widget.title == 'Promoted Parts') {
      return cubit.promotedPartsList;
    } else if (widget.title == translatedPromoted) {
      return cubit.promotedCarsList.where((item) => item.itemType == 'type_car').toList();
    } else if (widget.title == AppLang.tr(context, 'new_cars') || widget.title == "السيارات الجديدة" || widget.title == "New Cars") {
      return cubit.newCarsList;
    } else if (widget.title == AppLang.tr(context, 'used_cars') || widget.title == "السيارات المستعملة" || widget.title == "Used Cars") {
      return cubit.usedCarsList;
    } else if (widget.title == AppLang.tr(context, 'curated_for_you') || widget.title == "Cars for you") {
      return cubit.carsList.where((item) => item.itemType == 'type_car').toList();
    } else if (widget.title == AppLang.tr(context, 'top_rated_cars') || widget.title == "Top Rated Cars") {
      return await cubit.getActualTopRatedCars();
    } else {
      return cubit.carsList;
    }
  }

  void _initializeList(MarketCubit cubit) async {
    if (_isListInitialized) return;
    List<CarModel> source = await _getSourceList(cubit);

    List<CarModel> sortedSource = List.from(source)..sort((a, b) {
      DateTime dateA = DateTime.tryParse(a.createdAt) ?? DateTime.now();
      DateTime dateB = DateTime.tryParse(b.createdAt) ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    if (widget.title != AppLang.tr(context, 'top_rated_cars') && widget.title != "Top Rated Cars") {
      sortedSource.shuffle();
    }

    if (mounted) {
      setState(() {
        // بنعرض أول 10 عربيات بس في البداية عشان الشاشة تفتح طلقة
        _currentList = sortedSource.take(10).toList();
        _isListInitialized = true;
      });
    }
  }

  // 🔥 دالة الانفينتي اسكرول (اللوكال أولاً، ثم الـ API) 🔥
  void _loadMoreData() async {
    if (_isLoadingMoreLocal) return;
    setState(() { _isLoadingMoreLocal = true; });

    final cubit = context.read<MarketCubit>();
    bool isNewsScreen = widget.title == AppLang.tr(context, 'latest_cars_news') || widget.title == "News & Insights";

    if (isNewsScreen) {
      if (!cubit.isFetchingMoreNews) cubit.fetchMoreNews();
      setState(() { _isLoadingMoreLocal = false; });
      return;
    }

    // 1. بنبص في اللوكال الأول
    List<CarModel> source = await _getSourceList(cubit);
    var availableLocally = source.where((c) => !_currentList.any((existing) => existing.id == c.id)).toList();

    if (availableLocally.isNotEmpty) {
      // لو لقينا في اللوكال، بناخد 10 كمان ونعرضهم
      await Future.delayed(const Duration(milliseconds: 300)); // تأخير بسيط لجمال الـ UI
      if (mounted) {
        setState(() {
          _currentList.addAll(availableLocally.take(10));
          _isLoadingMoreLocal = false;
        });
      }
    } else {
      // 2. لو اللوكال خلص، بنكلم الـ API يولد عربيات جديدة (ما عدا التوب ريتيد والممول)
      bool isPromotedOrTopRated = widget.title == AppLang.tr(context, 'promoted') || widget.title == 'Promoted' || widget.title == AppLang.tr(context, 'top_rated_cars') || widget.title == 'Top Rated Cars' || widget.title == AppLang.tr(context, 'promoted_parts') || widget.title == 'Promoted Parts';

      if (!isPromotedOrTopRated) {
        bool isCategory = widget.title == AppLang.tr(context, 'new_cars') || widget.title == "السيارات الجديدة" || widget.title == "New Cars" || widget.title == AppLang.tr(context, 'used_cars') || widget.title == "السيارات المستعملة" || widget.title == "Used Cars";

        if (isCategory && !cubit.isSearchingCategoryAPI) {
          cubit.searchCategoryCarsFromAI("", widget.title);
        } else if (!cubit.isFetchingExternal) {
          cubit.fetchExternalCarsData();
        }
      }
      setState(() { _isLoadingMoreLocal = false; });
    }
  }

  void _triggerSearch(String query, MarketCubit cubit) {
    if (widget.title == AppLang.tr(context, 'promoted') || widget.title == 'Promoted' || widget.title == AppLang.tr(context, 'top_rated_cars') || widget.title == 'Top Rated Cars' || widget.title == AppLang.tr(context, 'promoted_parts') || widget.title == 'Promoted Parts') { return; }
    int localMatches = _currentList.where((car) {
      final String make = car.make.toLowerCase(); final String model = car.model.toLowerCase();
      final List<String> searchWords = cubit.parseSearchQuery(query)['words'];
      if (searchWords.isEmpty) return false;
      return searchWords.every((word) => make.contains(word) || model.contains(word));
    }).length;

    if (localMatches < 3) { cubit.searchCategoryCarsFromAI(query, widget.title); }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isListInitialized = false; _searchQuery = ""; _searchController.clear(); _selectedCompanies.clear(); _selectedPriceSort = 'الافتراضي';
    });
    await context.read<MarketCubit>().getCars();
    await context.read<MarketCubit>().getSpareParts(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isNewsScreen = widget.title == AppLang.tr(context, 'latest_cars_news') || widget.title == "News & Insights";
    final bool isTopRatedScreen = widget.title == AppLang.tr(context, 'top_rated_cars') || widget.title == "Top Rated Cars";
    String translatedPromotedParts = AppLang.tr(context, 'promoted_parts') ?? "قطع غيار ممولة";
    final bool isPartsScreen = widget.title == translatedPromotedParts || widget.title == 'Promoted Parts';
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);
    String displayTitle = AppLang.tr(context, widget.title) ?? widget.title;

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7),
                ),
                child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary),
              ),
            ),
          ],
        ),
      ),
      body: BlocConsumer<MarketCubit, MarketState>(
        listener: (context, state) {
          if (state is GetCarsSuccess || state is AddCarSuccess) {
            _isListInitialized = false;
            _initializeList(context.read<MarketCubit>());
          } else if (state is SearchCarsSuccess || state is FetchExternalCarsSuccess) {
            // لما الـ API يخلص ويرجع الداتا، بننده الدالة دي تسحب الداتا الجديدة من اللوكال وتعرضها
            _loadMoreData();
          }
        },
        builder: (context, state) {
          final marketCubit = context.read<MarketCubit>();

          if (!_isListInitialized && !isNewsScreen) {
            _initializeList(marketCubit);
          }

          if (isNewsScreen) {
            final sortedNews = List<NewsModel>.from(marketCubit.newsList);
            sortedNews.sort((a, b) { DateTime dateA = DateTime.tryParse(a.createdAt) ?? DateTime.now(); DateTime dateB = DateTime.tryParse(b.createdAt) ?? DateTime.now(); return dateB.compareTo(dateA); });
            final bool isFetchingMore = marketCubit.isFetchingMoreNews;

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark, AppLang.tr(context, 'latest_cars_news') ?? "أحدث أخبار السيارات", displayTitle),
                  Expanded(
                    child: RefreshIndicator(
                      key: _refreshIndicatorKey,
                      color: AppColors.primary,
                      onRefresh: () async => await marketCubit.getNews(),
                      child: sortedNews.isEmpty && marketCubit.isFetchingNews
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : sortedNews.isEmpty
                          ? _buildEmptyState(isNews: true)
                          : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: sortedNews.length + (isFetchingMore ? 1 : 0),
                        separatorBuilder: (context, index) => const SizedBox(height: 28),
                        itemBuilder: (context, index) {
                          if (index == sortedNews.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
                          final news = sortedNews[index];
                          String displayDate = news.date;
                          if (displayDate == 'الآن' || displayDate.isEmpty || displayDate.contains('hours') || displayDate.contains('ساعات')) { DateTime dt = DateTime.tryParse(news.createdAt) ?? DateTime.now(); displayDate = "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}"; }
                          return _buildLargeNewsCard(isDark, news.title, news.snippet, displayDate, news.imageUrl, news.articleUrl);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          else {
            bool isPromotedSection = widget.title == AppLang.tr(context, 'promoted') || isPartsScreen;
            List<CarModel> filteredCars = _currentList;

            List<String> availableCompanies = [];
            if (isPartsScreen) {
              Set<String> companiesSet = {};
              for (var part in _currentList) {
                if (part.model.isNotEmpty) {
                  String rawBrand = part.model.trim().split(' ').first.toUpperCase();
                  String cleanBrand = _brandNormalizer[rawBrand] ?? rawBrand;
                  if(cleanBrand.length > 1) companiesSet.add(cleanBrand);
                }
              }
              availableCompanies = companiesSet.toList()..sort();
            }

            if (_searchQuery.isNotEmpty) {
              final parsedData = marketCubit.parseSearchQuery(_searchQuery, isPart: isPartsScreen);
              final List<String> searchWords = parsedData['words'];
              final String? searchYear = parsedData['year'];

              filteredCars = filteredCars.where((car) {
                final String make = car.make.toLowerCase(); final String model = car.model.toLowerCase(); final String year = car.year.toString().toLowerCase();
                if (searchYear != null && year != searchYear) return false;
                if (searchWords.isNotEmpty) { return searchWords.every((word) => make.contains(word) || model.contains(word)); }
                return true;
              }).toList();
            }

            if (isPartsScreen) {
              if (_selectedCompanies.isNotEmpty) {
                filteredCars = filteredCars.where((part) {
                  String rawBrand = part.model.trim().split(' ').first.toUpperCase();
                  String cleanBrand = _brandNormalizer[rawBrand] ?? rawBrand;
                  return _selectedCompanies.contains(cleanBrand);
                }).toList();
              }
              if (_selectedPriceSort == 'الأقل سعراً' || _selectedPriceSort == (AppLang.tr(context, 'sort_lowest_price') ?? 'الأقل سعراً')) {
                filteredCars.sort((CarModel a, CarModel b) => (a.price ?? 0).compareTo(b.price ?? 0));
              } else if (_selectedPriceSort == 'الأعلى سعراً' || _selectedPriceSort == (AppLang.tr(context, 'sort_highest_price') ?? 'الأعلى سعراً')) {
                filteredCars.sort((CarModel a, CarModel b) => (b.price ?? 0).compareTo(a.price ?? 0));
              }
            }
            else if (isPromotedSection && marketCubit.isFilterActive) {
              filteredCars = filteredCars.where((car) {
                bool matchesBrand = marketCubit.selectedFilterBrands.isEmpty || marketCubit.selectedFilterBrands.any((brand) => car.make.toLowerCase().contains(brand.toLowerCase()));
                bool matchesPrice = marketCubit.selectedMaxPrice == null || car.price <= marketCubit.selectedMaxPrice!;
                return matchesBrand && matchesPrice;
              }).toList();
            }

            final bool isFetchingMoreApi = state is SearchCarsLoadingMore || state is FetchExternalCarsLoading || marketCubit.isSearchingCategoryAPI;
            final bool showLoadingIndicator = !_isListInitialized || (filteredCars.isEmpty && (isFetchingMoreApi || _isDebouncing));

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark, isTopRatedScreen ? (AppLang.tr(context, 'best_rated_2025') ?? "Best rated vehicles") : (AppLang.tr(context, 'explore_premium_selection') ?? "Explore our premium selection"), displayTitle),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: isDark ? Colors.white10 : Colors.transparent), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                            child: TextField(
                              controller: _searchController,
                              onTap: () => setState(() => _isSearchFocused = true),
                              onChanged: (value) {
                                setState(() { _searchQuery = value; _isDebouncing = true; });
                                if (_debounce?.isActive ?? false) _debounce!.cancel();
                                _debounce = Timer(const Duration(milliseconds: 1200), () {
                                  if (!mounted) return;
                                  setState(() { _isDebouncing = false; });
                                  if (_searchQuery.trim().isEmpty) return;
                                  _triggerSearch(_searchQuery, marketCubit);
                                });
                              },
                              onSubmitted: (value) {
                                if (_debounce?.isActive ?? false) _debounce!.cancel();
                                setState(() { _isSearchFocused = false; _isDebouncing = false; });
                                if (value.trim().isNotEmpty) { _triggerSearch(value, marketCubit); }
                              },
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: "${AppLang.tr(context, 'search_in')} $displayTitle...",
                                hintStyle: TextStyle(color: AppColors.textHint.withOpacity(0.7), fontSize: 15), prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 22),
                                suffixIcon: _searchQuery.isNotEmpty || _isSearchFocused ? _AnimatedClearSearchButton(onTap: () { _searchController.clear(); FocusScope.of(context).unfocus(); setState(() { _searchQuery = ""; _isSearchFocused = false; _isDebouncing = false; }); }) : null,
                                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),

                        if (isPromotedSection && !isPartsScreen) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const FiltersBottomSheet()); },
                            child: Container(
                              height: 50, width: 50,
                              decoration: BoxDecoration(color: marketCubit.isFilterActive ? const Color(0xFF1A237E) : AppColors.primary, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                              child: Stack(alignment: Alignment.center, children: [const Icon(Icons.tune, color: Colors.white, size: 22), if (marketCubit.isFilterActive) Positioned(top: 12, right: 12, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)))]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (isPartsScreen)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: GestureDetector(onTap: () => _showPremiumCompanyFilter(context, availableCompanies, isDark), child: _buildFilterButton(title: _selectedCompanies.isEmpty ? (AppLang.tr(context, 'company') ?? "الشركة") : "${AppLang.tr(context, 'companies') ?? 'الشركات'} (${_selectedCompanies.length})", isActive: _selectedCompanies.isNotEmpty, isDark: isDark))),
                          const SizedBox(width: 12),
                          Expanded(flex: 1, child: _buildPriceDropdownMenu(isDark: isDark)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _handleRefresh,
                      child: showLoadingIndicator
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : filteredCars.isEmpty
                          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [SizedBox(height: MediaQuery.of(context).size.height * 0.5, child: _buildEmptyState(isTopRated: isTopRatedScreen))])
                          : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        itemCount: filteredCars.length + (isFetchingMoreApi || _isLoadingMoreLocal ? 1 : 0),
                        separatorBuilder: (context, index) => const SizedBox(height: 28),
                        itemBuilder: (context, index) {
                          if (index == filteredCars.length) { return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: AppColors.primary))); }
                          if (isPartsScreen) { return PartCard(partItem: filteredCars[index], isPromoted: isPromotedSection); }
                          else { return _buildLargeCarCard(context: context, isDark: isDark, car: filteredCars[index], isPromoted: isPromotedSection, rating: filteredCars[index].tempRating, isTopRatedSection: isTopRatedScreen); }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  void _showPremiumCompanyFilter(BuildContext context, List<String> availableCompanies, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 30),
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLang.tr(context, 'filters') ?? "Filters", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () { setModalState(() { _selectedCompanies.clear(); }); setState(() { _selectedCompanies.clear(); }); },
                              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(AppLang.tr(context, 'clear_all') ?? "Clear All", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13))),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.grey[200], shape: BoxShape.circle), child: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54)))
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(AppLang.tr(context, 'company') ?? "COMPANY", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textHint, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 12, runSpacing: 12,
                          children: availableCompanies.map((company) {
                            final isSelected = _selectedCompanies.contains(company);
                            return GestureDetector(
                              onTap: () { setModalState(() { if (isSelected) { _selectedCompanies.remove(company); } else { _selectedCompanies.add(company); } }); setState(() {}); },
                              child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: (MediaQuery.of(context).size.width - 40 - 12) / 2, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF1E2834) : Colors.white), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey[300]!))), child: Center(child: Text(company, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 15)))),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, height: 54, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), onPressed: () => Navigator.pop(context), child: Text(AppLang.tr(context, 'apply_filters') ?? "Apply Filters", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))
                  ],
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildFilterButton({required String title, required bool isActive, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: isActive ? AppColors.primary : (isDark ? const Color(0xFF161E27) : Colors.white), borderRadius: BorderRadius.circular(20), border: Border.all(color: isActive ? AppColors.primary : (isDark ? Colors.white10 : Colors.transparent)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Flexible(child: Text(title, style: TextStyle(color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)), const SizedBox(width: 6), Icon(Icons.keyboard_arrow_down, color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87), size: 18)]),
    );
  }

  Widget _buildPriceDropdownMenu({required bool isDark}) {
    final defaultItem = AppLang.tr(context, 'sort_default') ?? 'الافتراضي';
    final items = [defaultItem, AppLang.tr(context, 'sort_lowest_price') ?? 'الأقل سعراً', AppLang.tr(context, 'sort_highest_price') ?? 'الأعلى سعراً'];
    bool isActive = _selectedPriceSort != 'الافتراضي' && _selectedPriceSort != defaultItem;
    String displayTitle = isActive ? _selectedPriceSort : (AppLang.tr(context, 'price') ?? "السعر");

    return PopupMenuButton<String>(
      onSelected: (val) => setState(() => _selectedPriceSort = val),
      color: isDark ? const Color(0xFF161E27) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
      itemBuilder: (context) {
        return items.map((item) {
          bool isSelected = item == _selectedPriceSort || (item == defaultItem && _selectedPriceSort == 'الافتراضي');
          return PopupMenuItem<String>(value: item, child: Text(item, style: TextStyle(color: isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)));
        }).toList();
      },
      child: _buildFilterButton(title: displayTitle, isActive: isActive, isDark: isDark),
    );
  }

  Widget _buildHeader(bool isDark, String subtitle, String displayTitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 10.0, bottom: 10.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayTitle, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 32), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]
      ),
    );
  }

  Widget _buildEmptyState({bool isNews = false, bool isTopRated = false}) {
    IconData emptyIcon = Icons.search_off_rounded;
    String emptyText = AppLang.tr(context, 'no_cars_to_show') ?? "No cars";

    if (isNews) { emptyIcon = Icons.newspaper; emptyText = AppLang.tr(context, 'no_news_available') ?? 'No news available'; }
    else if (isTopRated && _searchQuery.isEmpty) { emptyIcon = Icons.star_border_rounded; emptyText = AppLang.tr(context, 'no_rated_cars_yet') ?? 'No rated cars yet'; }
    else if (_searchQuery.isNotEmpty) { emptyIcon = Icons.search_off_rounded; emptyText = AppLang.tr(context, 'no_matching_cars_found') ?? 'No matching cars found'; }

    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(emptyIcon, size: 80, color: AppColors.textHint.withOpacity(0.3)), const SizedBox(height: 20), Text(emptyText, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHint, fontSize: 18))]));
  }

  Widget _buildFAB() {
    return FloatingActionButton(onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const AiChatBottomSheet()), backgroundColor: AppColors.primary, child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28));
  }

  Widget _buildLargeNewsCard(bool isDark, String title, String desc, String date, String imageUrl, String articleUrl) {
    return GestureDetector(
      onTap: () async { try { final Uri uri = Uri.parse(articleUrl); if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (e) { print("Error: $e"); } },
      child: Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white10 : Colors.transparent), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(20), child: CachedNetworkImage(imageUrl: imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: AppColors.primary)), errorWidget: (context, url, error) => Container(height: 200, color: Colors.grey, child: const Icon(Icons.newspaper, size: 80)))),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)), child: Text(date, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(desc, style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 14, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeCarCard({required BuildContext context, required bool isDark, required CarModel car, double? rating, bool isPromoted = false, bool isTopRatedSection = false}) {
    final price = "${AppLang.tr(context, 'currency_egp') ?? 'EGP'} ${car.price.toStringAsFixed(0)}";
    final imageUrl = car.images.isNotEmpty ? car.images.first : null;
    const fallbackImage = 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?q=80&w=800&auto=format&fit=crop';
    final cubit = context.read<MarketCubit>();

    Color cardBgColor = isPromoted ? (isDark ? const Color(0xFF3E3220) : const Color(0xFFFFF9E6)) : (isDark ? const Color(0xFF161E27) : Colors.white);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CarDetailsScreen(car: car, isPromoted: isPromoted))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? Colors.white10 : Colors.transparent), boxShadow: [BoxShadow(color: isPromoted ? const Color(0xFFF39C12).withOpacity(isDark ? 0.2 : 0.15) : Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl != null && imageUrl.isNotEmpty ? CachedNetworkImage(imageUrl: imageUrl, height: 230, width: double.infinity, fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: AppColors.primary)), errorWidget: (c, u, e) => CachedNetworkImage(imageUrl: fallbackImage, height: 230, width: double.infinity, fit: BoxFit.cover)) : CachedNetworkImage(imageUrl: fallbackImage, height: 230, width: double.infinity, fit: BoxFit.cover),
                ),
                if (isTopRatedSection)
                  PositionedDirectional(
                    top: 16, start: 16,
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, color: Colors.white, size: 14), const SizedBox(width: 4), Text(AppLang.tr(context, 'top_rated_badge') ?? 'Top Rated', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))])),
                  ),
                PositionedDirectional(
                  top: 16, end: 16,
                  child: BlocBuilder<MarketCubit, MarketState>(
                    builder: (context, state) {
                      bool isSaved = cubit.isCarSaved(car.id); bool isCompared = cubit.isCarInCompare(car.id);
                      return Column(
                        children: [
                          _buildIconButton(icon: isSaved ? Icons.favorite : Icons.favorite_border, iconColor: isSaved ? Colors.redAccent : (isDark ? Colors.white : AppColors.secondary), isDark: isDark, onTap: () => cubit.toggleSavedCar(car)),
                          const SizedBox(height: 12),
                          _buildIconButton(icon: Icons.compare_arrows, iconColor: isCompared ? Colors.white : (isDark ? Colors.white : AppColors.secondary), isDark: isDark, backgroundColor: isCompared ? AppColors.primary : null, onTap: () => cubit.toggleCompareCar(car, context)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(car.make.toUpperCase(), style: const TextStyle(color: AppColors.textHint, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Text(car.model, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(car.year, style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  if (rating != null && rating > 0)
                    Row(children: [const Icon(Icons.star, color: Colors.orange, size: 20), const SizedBox(width: 6), Text(rating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87))])
                ]
            ),
            const SizedBox(height: 24),
            Text(price, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 22)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required Color iconColor, required bool isDark, required VoidCallback onTap, Color? backgroundColor}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: backgroundColor ?? (isDark ? const Color(0xFF1E2834) : Colors.white), shape: BoxShape.circle, border: backgroundColor != null ? Border.all(color: isDark ? Colors.white24 : Colors.blue[100]!, width: 2) : Border.all(color: isDark ? Colors.white10 : Colors.transparent), boxShadow: [BoxShadow(color: backgroundColor != null ? AppColors.primary.withOpacity(isDark ? 0.3 : 0.1) : Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5, offset: const Offset(0, 2))]),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

class _AnimatedClearSearchButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedClearSearchButton({required this.onTap});
  @override
  State<_AnimatedClearSearchButton> createState() => _AnimatedClearSearchButtonState();
}

class _AnimatedClearSearchButtonState extends State<_AnimatedClearSearchButton> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) { setState(() => _isHovered = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _isHovered ? Colors.red.withOpacity(0.15) : Colors.transparent, shape: BoxShape.circle),
        child: Icon(Icons.close, color: _isHovered ? Colors.red : AppColors.textHint, size: 20),
      ),
    );
  }
}