import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../home/widgets/part_card.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../home/screens/view_all_cars_screen.dart';
import '../../profile/screens/start_selling_screen.dart';
import '../../marketplace/models/car_model.dart';
import '../../home/screens/saved_parts_screen.dart';
import '../../auth/screens/login_screen.dart';

class PartsScreen extends StatefulWidget {
  const PartsScreen({super.key});

  @override
  State<PartsScreen> createState() => _PartsScreenState();
}

class _PartsScreenState extends State<PartsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";
  Timer? _debounce;
  List<String> _recentSearches = [];

  static const String _searchHistoryKey = 'gear_up_parts_recent_searches_persistent';
  static const int _maxRecentSearches = 10;
  bool _isSearchFocused = false;

  List<String> _selectedCompanies = [];
  String _selectedPriceSort = 'الافتراضي';

  final List<String> _availableBrands = [
    "TOYOTA", "HYUNDAI", "BMW", "KIA", "MERCEDES", "NISSAN",
    "CHEVROLET", "SKODA", "VOLKSWAGEN", "RENAULT", "PEUGEOT",
    "MAZDA", "JEEP", "FORD", "FIAT", "AUDI"
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<MarketCubit>().carsList.isEmpty) {
        context.read<MarketCubit>().getCars();
      }
      context.read<MarketCubit>().getSpareParts();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        _triggerSearchOrLoadMore(isLoadMore: true);
      }
    });
  }

  // 🔥 دالة سحرية بتدمج السيرش مع الفلتر وتبعتهم للسيرفر صح 🔥
  void _triggerSearchOrLoadMore({bool isLoadMore = false}) {
    final cubit = context.read<MarketCubit>();
    String finalQuery = "";

    if (_searchQuery.isNotEmpty && _selectedCompanies.isNotEmpty) {
      finalQuery = "${_searchQuery.trim()} متوافقة مع ${_selectedCompanies.join(' او ')}";
    } else if (_searchQuery.isNotEmpty) {
      finalQuery = "قطع غيار ${_searchQuery.trim()}";
    } else if (_selectedCompanies.isNotEmpty) {
      finalQuery = "قطع غيار متوافقة مع ${_selectedCompanies.join(' او ')}";
    }

    if (finalQuery.isNotEmpty) {
      cubit.searchSpecificCar(finalQuery, isLoadMore: isLoadMore);
    } else if (isLoadMore) {
      cubit.loadMoreSpareParts();
    } else {
      cubit.searchResults.clear();
      cubit.emit(SearchCarsSuccess());
    }
  }

  void _loadRecentSearches() {
    setState(() { _recentSearches = CacheHelper.getStringList(key: _searchHistoryKey) ?? []; });
  }

  Future<void> _saveSearchTerm(String term) async {
    final text = term.trim();
    if (text.isEmpty) return;
    List<String> history = CacheHelper.getStringList(key: _searchHistoryKey) ?? [];
    history.remove(text); history.insert(0, text);
    if (history.length > _maxRecentSearches) history = history.sublist(0, _maxRecentSearches);
    await CacheHelper.saveData(key: _searchHistoryKey, value: history);
    setState(() { _recentSearches = history; });
  }

  Future<void> _deleteSearchTerm(String term) async {
    List<String> history = CacheHelper.getStringList(key: _searchHistoryKey) ?? [];
    history.remove(term);
    await CacheHelper.saveData(key: _searchHistoryKey, value: history);
    setState(() { _recentSearches = history; });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    _searchController.clear();
    setState(() {
      _searchQuery = ""; _isSearchFocused = false;
      _selectedCompanies.clear(); _selectedPriceSort = 'الافتراضي';
    });
    FocusScope.of(context).unfocus();
    await context.read<MarketCubit>().getSpareParts(isRefresh: true);
  }

  void _showGuestDialog(BuildContext context, String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text("تسجيل الدخول مطلوب", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 12),
              Text("عفواً، لا يمكنك $featureName كزائر. قم بتسجيل الدخول!", textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                },
                child: const Text("تسجيل الدخول"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInterleavedFeed(BuildContext context, bool isDark, List<CarModel> vips, List<CarModel> normals) {
    List<Widget> feedWidgets = [];
    int normalIndex = 0;
    int vipIndex = 0;
    bool isFirstBatch = true;

    while (normalIndex < normals.length || vipIndex < vips.length) {
      if (vipIndex < vips.length) {
        List<CarModel> currentVipsToDisplay = vips.skip(vipIndex).take(2).toList();
        feedWidgets.add(_buildPromotedPartsSection(context, isDark, currentVipsToDisplay));
        feedWidgets.add(const SizedBox(height: 24));
        vipIndex += 2;
      }

      if (isFirstBatch && normals.isNotEmpty) {
        feedWidgets.add(Text("المضاف حديثاً", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)));
        feedWidgets.add(const SizedBox(height: 16));
        isFirstBatch = false;
      }

      int normalBatchCount = 0;
      while (normalBatchCount < 15 && normalIndex < normals.length) {
        feedWidgets.add(PartCard(partItem: normals[normalIndex], isPromoted: false));
        feedWidgets.add(const SizedBox(height: 12));
        normalIndex++;
        normalBatchCount++;
      }

      if (normalIndex < normals.length && vipIndex < vips.length) {
        feedWidgets.add(const SizedBox(height: 24));
      }
    }
    return feedWidgets;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: screenBgColor,
      body: SafeArea(
        child: BlocBuilder<MarketCubit, MarketState>(
          builder: (context, state) {
            final cubit = context.read<MarketCubit>();
            final List<CarModel> promotedParts = cubit.promotedPartsList;
            List<CarModel> normalParts = cubit.sparePartsList.where((p) => !promotedParts.any((vip) => vip.id == p.id)).toList();

            List<CarModel> displayParts = [];
            bool isFilteringOrSearching = _searchQuery.isNotEmpty || _selectedCompanies.isNotEmpty;

            // 🔥 اللوجيك النظيف لعرض النتائج 🔥
            if (isFilteringOrSearching) {
              // بناخد النتايج اللي السيرفر جابها بناءً على الفلتر/السيرش
              displayParts.addAll(cubit.searchResults.where((e) => e.itemType == 'type_spare_part').toList());

              // فلترة إضافية محلية للتأكيد
              if (_selectedCompanies.isNotEmpty) {
                displayParts = displayParts.where((part) {
                  return _selectedCompanies.any((company) =>
                  part.model.toUpperCase().contains(company) || part.make.toUpperCase().contains(company) || part.description.toUpperCase().contains(company)
                  );
                }).toList();
              }
            } else {
              displayParts.addAll(normalParts);
            }

            if (_selectedPriceSort == 'الأقل سعراً') {
              displayParts.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
            } else if (_selectedPriceSort == 'الأعلى سعراً') {
              displayParts.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
            }

            final isLoading = state is SearchCarsLoading || cubit.isFetchingParts;
            final isFetchingMore = state is SearchCarsLoadingMore || cubit.isFetchingMoreParts;
            final bool showEmptyState = isFilteringOrSearching ? displayParts.isEmpty : (promotedParts.isEmpty && displayParts.isEmpty);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("قطع الغيار", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      Text("${cubit.sparePartsList.length} قطعة متوفرة", style: const TextStyle(fontSize: 14, color: AppColors.textHint)),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(26)),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      onTap: () => setState(() => _isSearchFocused = true),
                      onChanged: (value) {
                        setState(() { _searchQuery = value; });
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(const Duration(milliseconds: 1200), () {
                          _triggerSearchOrLoadMore();
                        });
                      },
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) { _saveSearchTerm(value); _triggerSearchOrLoadMore(); }
                        setState(() => _isSearchFocused = false);
                      },
                      decoration: InputDecoration(
                        hintText: "ابحث عن قطع الغيار...",
                        prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                        suffixIcon: _searchQuery.isNotEmpty || _isSearchFocused ? IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textHint, size: 20),
                          onPressed: () {
                            _searchController.clear(); FocusScope.of(context).unfocus();
                            setState(() { _searchQuery = ""; _isSearchFocused = false; });
                            _triggerSearchOrLoadMore();
                          },
                        ) : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (!_isSearchFocused) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: GestureDetector(onTap: () => _showPremiumCompanyFilter(context, isDark), child: _buildFilterButton(title: _selectedCompanies.isEmpty ? "الشركة" : "الشركات (${_selectedCompanies.length})", isActive: _selectedCompanies.isNotEmpty, isDark: isDark))),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: _buildPriceDropdownMenu(isDark: isDark)),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () {
                              if (CacheHelper.getData(key: 'uid') == null) { _showGuestDialog(context, "عرض المحفوظات"); return; }
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPartsScreen()));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.build_outlined, color: AppColors.primary, size: 18),
                                const SizedBox(width: 4),
                                Flexible(child: Text("المحفوظة", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Expanded(
                  child: _isSearchFocused && _searchQuery.isEmpty && _recentSearches.isNotEmpty
                      ? ListView.builder(
                    itemCount: _recentSearches.length,
                    itemBuilder: (context, index) {
                      final term = _recentSearches[index];
                      return ListTile(
                        leading: const Icon(Icons.history, color: AppColors.textHint),
                        title: Text(term, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                        trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => _deleteSearchTerm(term)),
                        onTap: () {
                          _searchController.text = term; _saveSearchTerm(term);
                          setState(() { _searchQuery = term; _isSearchFocused = false; });
                          _triggerSearchOrLoadMore();
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  )
                      : RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: isLoading && displayParts.isEmpty
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : showEmptyState
                        ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.build_circle_outlined, size: 80, color: Colors.grey),
                                SizedBox(height: 20),
                                Text("لا توجد نتائج، قم بتغيير الفلتر أو ابحث مرة أخرى", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                        : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (!isFilteringOrSearching && _selectedPriceSort == 'الافتراضي')
                          ..._buildInterleavedFeed(context, isDark, promotedParts, displayParts)
                        else ...[
                          Text("نتائج البحث والفلتر", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 16),
                          ...displayParts.map((part) => Column(children: [PartCard(partItem: part), const SizedBox(height: 12)])).toList(),
                        ],

                        if (isFetchingMore)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),

                        if (!isFetchingMore && displayParts.isNotEmpty && isFilteringOrSearching)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: OutlinedButton.icon(
                              onPressed: () => _triggerSearchOrLoadMore(isLoadMore: true),
                              icon: const Icon(Icons.refresh, color: AppColors.primary),
                              label: const Text("تحميل المزيد من النتائج", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                              ),
                            ),
                          ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 🔥 الفلتر اللي بيكلم السيرفر بمجرد ما تدوس تطبيق 🔥
  void _showPremiumCompanyFilter(BuildContext context, bool isDark) {
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
                        Text("الشركات", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setModalState(() { _selectedCompanies.clear(); });
                                setState(() { _selectedCompanies.clear(); });
                                _triggerSearchOrLoadMore();
                              },
                              child: const Text("مسح الكل", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54))
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 12, runSpacing: 12,
                          children: _availableBrands.map((company) {
                            final isSelected = _selectedCompanies.contains(company);
                            return GestureDetector(
                              onTap: () {
                                setModalState(() { isSelected ? _selectedCompanies.remove(company) : _selectedCompanies.add(company); });
                                setState(() {});
                              },
                              child: Container(
                                width: (MediaQuery.of(context).size.width - 40 - 12) / 2,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF1E2834) : Colors.white),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey[300]!)),
                                ),
                                child: Center(child: Text(company, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold))),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () {
                          Navigator.pop(context);
                          _triggerSearchOrLoadMore(); // السحر هنا!
                        },
                        child: const Text("تطبيق الفلتر", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : (isDark ? const Color(0xFF161E27) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? AppColors.primary : (isDark ? Colors.white10 : Colors.transparent)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(title, style: TextStyle(color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87), size: 16),
        ],
      ),
    );
  }

  Widget _buildPriceDropdownMenu({required bool isDark}) {
    final items = ['الافتراضي', 'الأقل سعراً', 'الأعلى سعراً'];
    bool isActive = _selectedPriceSort != 'الافتراضي';
    return PopupMenuButton<String>(
      onSelected: (val) => setState(() => _selectedPriceSort = val),
      color: isDark ? const Color(0xFF161E27) : Colors.white,
      itemBuilder: (context) => items.map((item) => PopupMenuItem(value: item, child: Text(item, style: TextStyle(color: item == _selectedPriceSort ? AppColors.primary : (isDark ? Colors.white : Colors.black87), fontWeight: item == _selectedPriceSort ? FontWeight.bold : FontWeight.normal)))).toList(),
      child: _buildFilterButton(title: isActive ? _selectedPriceSort : "السعر", isActive: isActive, isDark: isDark),
    );
  }

  Widget _buildPromotedPartsSection(BuildContext context, bool isDark, List<CarModel> promotedPartsToDisplay) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2416) : const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? const Color(0xFF4A3A20) : const Color(0xFFFFE082))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text("ممولة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFD35400))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFFFF9800) : const Color(0xFFF39C12), borderRadius: BorderRadius.circular(8)),
                    child: Text("Featured Listings", style: TextStyle(color: isDark ? Colors.black87 : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...promotedPartsToDisplay.map((part) => Column(children: [PartCard(partItem: part, isPromoted: true), const SizedBox(height: 12)])).toList(),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ViewAllCarsScreen(title: "قطع غيار ممولة"))); },
                  icon: Icon(Icons.keyboard_arrow_down, color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFD35400)),
                  label: Text("عرض المزيد", style: TextStyle(color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFD35400), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.premiumGoldStart, AppColors.premiumGoldEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: AppColors.premiumGoldShadow, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                if (CacheHelper.getData(key: 'uid') == null) { _showGuestDialog(context, "نشر إعلانات"); return; }
                Navigator.push(context, MaterialPageRoute(builder: (context) => const StartSellingScreen(initialItemType: 'type_part')));
              },
              icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary, size: 20),
              label: const Text("ابدأ البيع الآن", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
        ],
      ),
    );
  }
}