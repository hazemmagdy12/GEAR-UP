abstract class MarketState {}

// ==========================================
// 🔥 الحالات العامة (General States) 🔥
// ==========================================
class MarketInitial extends MarketState {}

class MarketGeneralError extends MarketState {
  final String error;
  MarketGeneralError(this.error);
}

// ==========================================
// 🔥 حالات السيارات والبيانات الأساسية 🔥
// ==========================================
class GetCarsLoading extends MarketState {}
class GetCarsSuccess extends MarketState {}
class GetCarsError extends MarketState {
  final String error;
  GetCarsError(this.error);
}

class FetchExternalCarsLoading extends MarketState {}
class FetchExternalCarsSuccess extends MarketState {}
class FetchExternalCarsError extends MarketState {
  final String error;
  FetchExternalCarsError(this.error);
}

class CarDescriptionUpdatedState extends MarketState {}

// ==========================================
// 🔥 حالات إضافة إعلان (سيارة/قطعة غيار) 🔥
// ==========================================
class AddCarLoading extends MarketState {}
class AddCarSuccess extends MarketState {}
class AddCarError extends MarketState {
  final String error;
  AddCarError(this.error);
}

class CarImagePickedSuccess extends MarketState {}
class CarImagePickedError extends MarketState {
  final String error;
  CarImagePickedError(this.error);
}

// ==========================================
// 🔥 حالات محرك البحث الذكي 🔥
// ==========================================
class SearchCarsLoading extends MarketState {}
class SearchCarsLoadingMore extends MarketState {}
class SearchCarsSuccess extends MarketState {}
class SearchCarsError extends MarketState {
  final String error;
  SearchCarsError(this.error);
}

// ==========================================
// 🔥 حالات الفلتر المتقدم 🔥
// ==========================================
class FilterSelectionChanged extends MarketState {}
class FilterCarsLoading extends MarketState {}
class FilterCarsLoadingMore extends MarketState {}
class FilterCarsSuccess extends MarketState {}

// ==========================================
// 🔥 حالات الحفظ (Saved) والمقارنة (Compare) 🔥
// ==========================================
class SavedCarsLoading extends MarketState {}
class SavedCarsSuccess extends MarketState {}
class SavedCarsError extends MarketState {
  final String error;
  SavedCarsError(this.error);
}

class CompareCarsUpdated extends MarketState {}

// ==========================================
// 🔥 حالات التقييمات (Reviews) 🔥
// ==========================================
class MyReviewsLoadingState extends MarketState {}
class MyReviewsLoadedState extends MarketState {}
class MarketLoading extends MarketState {}
class MarketLoaded extends MarketState {}