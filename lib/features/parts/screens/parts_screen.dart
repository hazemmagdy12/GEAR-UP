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
    _loadRecentSearches();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<MarketCubit>().carsList.isEmpty) {
        context.read<MarketCubit>().getCars();
      }
      context.read<MarketCubit>().getSpareParts();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        context.read<MarketCubit>().loadMoreSpareParts(query: _searchQuery);
      }
    });
  }

  void _loadRecentSearches() {
    setState(() {
      _recentSearches = CacheHelper.getStringList(key: _searchHistoryKey) ?? [];
    });
  }

  Future<void> _saveSearchTerm(String term) async {
    final text = term.trim();
    if (text.isEmpty) return;

    List<String> history = CacheHelper.getStringList(key: _searchHistoryKey) ?? [];
    history.remove(text);
    history.insert(0, text);
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
      _searchQuery = "";
      _isSearchFocused = false;
      _selectedCompanies.clear();
      _selectedPriceSort = 'الافتراضي'; // Default
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
        elevation: isDark ? 0 : 10,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                AppLang.tr(context, 'login_required') ?? "تسجيل الدخول مطلوب",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "${AppLang.tr(context, 'guest_sorry_prefix') ?? 'عفواً، لا يمكنك'} $featureName ${AppLang.tr(context, 'guest_sorry_suffix') ?? 'كزائر. قم بتسجيل الدخول لتستمتع بجميع مميزات GEAR UP! 🚗✨'}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(AppLang.tr(context, 'login') ?? "تسجيل الدخول", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    AppLang.tr(context, 'cancel_btn') ?? "إلغاء",
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
        feedWidgets.add(
          Text(AppLang.tr(context, 'recently_added') ?? "المضاف حديثاً", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
        );
        feedWidgets.add(const SizedBox(height: 16));
        isFirstBatch = false;
      }

      int normalBatchCount = 0;
      while (normalBatchCount < 15 && normalIndex < normals.length) {
        feedWidgets.add(PartCard(partItem: normals[normalIndex], isPromoted: false));
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
            if (_searchQuery.isNotEmpty) {
              displayParts.addAll(cubit.partsSearchResults);
            } else {
              displayParts.addAll(normalParts);
            }

            Set<String> companiesSet = {};
            for (var part in cubit.sparePartsList) {
              if (part.model.isNotEmpty) {
                String rawBrand = part.model.trim().split(' ').first.toUpperCase();
                String cleanBrand = _brandNormalizer[rawBrand] ?? rawBrand;
                if(cleanBrand.length > 1) companiesSet.add(cleanBrand);
              }
            }
            List<String> availableCompanies = companiesSet.toList();
            availableCompanies.sort();

            if (_selectedCompanies.isNotEmpty) {
              displayParts = displayParts.where((part) {
                String rawBrand = part.model.trim().split(' ').first.toUpperCase();
                String cleanBrand = _brandNormalizer[rawBrand] ?? rawBrand;
                return _selectedCompanies.contains(cleanBrand);
              }).toList();
            }

            // التعامل مع ترتيب الأسعار باستخدام اللغات المختلفة (عربي/إنجليزي)
            if (_selectedPriceSort == (AppLang.tr(context, 'sort_lowest_price') ?? 'الأقل سعراً') || _selectedPriceSort == 'الأقل سعراً') {
              displayParts.sort((CarModel a, CarModel b) => (a.price ?? 0).compareTo(b.price ?? 0));
            } else if (_selectedPriceSort == (AppLang.tr(context, 'sort_highest_price') ?? 'الأعلى سعراً') || _selectedPriceSort == 'الأعلى سعراً') {
              displayParts.sort((CarModel a, CarModel b) => (b.price ?? 0).compareTo(a.price ?? 0));
            }

            final isLoading = state is SearchCarsLoading || cubit.isFetchingParts;
            final isFetchingMore = cubit.isFetchingMoreParts;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLang.tr(context, 'car_parts') ?? "قطع الغيار", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      Text("${cubit.sparePartsList.length} ${AppLang.tr(context, 'parts_available') ?? 'قطعة متوفرة'}", style: const TextStyle(fontSize: 14, color: AppColors.textHint)),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 52,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161E27) : Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      textAlignVertical: TextAlignVertical.center,
                      onTap: () => setState(() => _isSearchFocused = true),
                      onChanged: (value) {
                        setState(() { _searchQuery = value; });
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(const Duration(milliseconds: 1200), () {
                          if (_searchQuery.trim().isEmpty) {
                            cubit.partsSearchResults.clear();
                            setState(() {});
                          } else {
                            cubit.searchSpareParts(_searchQuery);
                          }
                        });
                      },
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _saveSearchTerm(value);
                          cubit.searchSpareParts(value.trim());
                        }
                        setState(() => _isSearchFocused = false);
                      },
                      decoration: InputDecoration(
                        hintText: AppLang.tr(context, 'search_parts') ?? "ابحث عن قطع الغيار...",
                        hintStyle: const TextStyle(color: AppColors.textHint),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                        suffixIcon: _searchQuery.isNotEmpty || _isSearchFocused
                            ? _AnimatedClearSearchButton(
                          onTap: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                            setState(() { _searchQuery = ""; _isSearchFocused = false; });
                            cubit.partsSearchResults.clear();
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () => _showPremiumCompanyFilter(context, availableCompanies, isDark),
                            child: _buildFilterButton(
                              title: _selectedCompanies.isEmpty ? (AppLang.tr(context, 'company') ?? "الشركة") : "${AppLang.tr(context, 'companies') ?? 'الشركات'} (${_selectedCompanies.length})",
                              isActive: _selectedCompanies.isNotEmpty,
                              isDark: isDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          flex: 3,
                          child: _buildPriceDropdownMenu(isDark: isDark),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () {
                              if (CacheHelper.getData(key: 'uid') == null) {
                                _showGuestDialog(context, AppLang.tr(context, 'saved_parts') ?? "عرض المحفوظات");
                                return;
                              }
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPartsScreen()));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF161E27) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.build_outlined, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      AppLang.tr(context, 'saved_parts') ?? "القطع المحفوظة",
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: isDark ? Colors.white10 : Colors.black12, thickness: 1),
                  ),
                ],

                Expanded(
                  child: _isSearchFocused && _searchQuery.isEmpty && _recentSearches.isNotEmpty
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.history, size: 16, color: AppColors.textHint),
                            const SizedBox(width: 8),
                            Text(AppLang.tr(context, 'recent_searches') ?? "سجل البحث", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textHint)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _recentSearches.length,
                          itemBuilder: (context, index) {
                            final term = _recentSearches[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                              leading: const Icon(Icons.search, color: AppColors.textHint, size: 20),
                              title: Text(term, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
                              trailing: _PremiumDeleteButton(onTap: () => _deleteSearchTerm(term)),
                              onTap: () {
                                _searchController.text = term;
                                _saveSearchTerm(term);
                                cubit.searchSpareParts(term);
                                FocusScope.of(context).unfocus();
                                setState(() { _searchQuery = term; _isSearchFocused = false; });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  )
                      : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _handleRefresh,
                    child: isLoading && displayParts.isEmpty
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : (promotedParts.isEmpty && displayParts.isEmpty)
                        ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.build_circle_outlined, size: 80, color: AppColors.textHint.withOpacity(0.3)),
                                  const SizedBox(height: 20),
                                  Text(AppLang.tr(context, 'no_parts_to_show') ?? "لا توجد نتائج مطابقة", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHint, fontSize: 18)),
                                ],
                              ),
                            ),
                          ),
                        ]
                    )
                        : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [

                        if (_searchQuery.isEmpty && _selectedCompanies.isEmpty && (_selectedPriceSort == 'الافتراضي' || _selectedPriceSort == (AppLang.tr(context, 'sort_default') ?? 'الافتراضي')))
                          ..._buildInterleavedFeed(context, isDark, promotedParts, displayParts)
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  AppLang.tr(context, 'search_filter_results') ?? "نتائج البحث والفلتر",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...displayParts.map((part) => PartCard(partItem: part)).toList(),
                        ],

                        if (isFetchingMore)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),

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
                              onTap: () {
                                setModalState(() { _selectedCompanies.clear(); });
                                setState(() { _selectedCompanies.clear(); });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12)
                                ),
                                child: Text(AppLang.tr(context, 'clear_all') ?? "Clear All", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[200], shape: BoxShape.circle),
                                child: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                              ),
                            )
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
                          spacing: 12,
                          runSpacing: 12,
                          children: availableCompanies.map((company) {
                            final isSelected = _selectedCompanies.contains(company);
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    _selectedCompanies.remove(company);
                                  } else {
                                    _selectedCompanies.add(company);
                                  }
                                });
                                setState(() {});
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: (MediaQuery.of(context).size.width - 40 - 12) / 2,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF1E2834) : Colors.white),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey[300]!)),
                                ),
                                child: Center(
                                  child: Text(
                                      company,
                                      style: TextStyle(
                                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 15
                                      )
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppLang.tr(context, 'apply_filters') ?? "Apply Filters", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black87),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceDropdownMenu({required bool isDark}) {
    final defaultItem = AppLang.tr(context, 'sort_default') ?? 'الافتراضي';
    final items = [
      defaultItem,
      AppLang.tr(context, 'sort_lowest_price') ?? 'الأقل سعراً',
      AppLang.tr(context, 'sort_highest_price') ?? 'الأعلى سعراً'
    ];
    bool isActive = _selectedPriceSort != 'الافتراضي' && _selectedPriceSort != defaultItem;
    String displayTitle = isActive ? _selectedPriceSort : (AppLang.tr(context, 'price') ?? "السعر");

    return PopupMenuButton<String>(
      onSelected: (val) => setState(() => _selectedPriceSort = val),
      color: isDark ? const Color(0xFF161E27) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
      itemBuilder: (context) {
        return items.map((item) {
          bool isSelected = item == _selectedPriceSort || (item == defaultItem && _selectedPriceSort == 'الافتراضي');
          return PopupMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: TextStyle(
                color: isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList();
      },
      child: _buildFilterButton(title: displayTitle, isActive: isActive, isDark: isDark),
    );
  }

  Widget _buildPromotedPartsSection(BuildContext context, bool isDark, List<CarModel> promotedPartsToDisplay) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2416) : const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? const Color(0xFF4A3A20) : const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(AppLang.tr(context, 'promoted') ?? "Promoted", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFD35400))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFFFF9800) : const Color(0xFFF39C12), borderRadius: BorderRadius.circular(8)),
                    child: Text(AppLang.tr(context, 'featured_listings') ?? "Featured Listings", style: TextStyle(color: isDark ? Colors.black87 : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...promotedPartsToDisplay.map((part) => Column(
            children: [
              PartCard(partItem: part, isPromoted: true),
              const SizedBox(height: 12),
            ],
          )).toList(),

          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ViewAllCarsScreen(title: AppLang.tr(context, 'promoted_parts') ?? "قطع غيار ممولة")));
                  },
                  icon: Icon(Icons.keyboard_arrow_down, color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFD35400)),
                  label: Text(AppLang.tr(context, 'view_more') ?? "View More", style: TextStyle(color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFD35400), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.premiumGoldStart, AppColors.premiumGoldEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: AppColors.premiumGoldShadow, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                if (CacheHelper.getData(key: 'uid') == null) {
                  _showGuestDialog(context, AppLang.tr(context, 'publish_ads_feature') ?? "نشر إعلانات");
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (context) => const StartSellingScreen(initialItemType: 'type_part')));
              },
              icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary, size: 20),
              label: Text(
                AppLang.tr(context, 'start_ad_now') ?? "Start Selling Now",
                style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
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
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.red.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          color: _isHovered ? Colors.red : AppColors.textHint,
          size: 20,
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) { setState(() => _isHovered = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.red.withOpacity(0.9) : Colors.red.withOpacity(0.15),
          shape: BoxShape.circle,
          boxShadow: _isHovered ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)] : [],
        ),
        child: Icon(
            Icons.close_rounded,
            color: _isHovered ? Colors.white : Colors.redAccent,
            size: 16
        ),
      ),
    );
  }
}