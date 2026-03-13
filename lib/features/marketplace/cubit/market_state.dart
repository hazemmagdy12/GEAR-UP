abstract class MarketState {}

class MarketInitial extends MarketState {}
class CarDescriptionUpdatedState extends MarketState {}
class MyReviewsLoadingState extends MarketState {}
class MyReviewsLoadedState extends MarketState {}
class AddCarLoading extends MarketState {}
class AddCarSuccess extends MarketState {}
class AddCarError extends MarketState {
  final String error;
  AddCarError(this.error);
}

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

// 🔥 حالات محرك البحث الذكي 🔥
class SearchCarsLoading extends MarketState {}
class SearchCarsLoadingMore extends MarketState {}
class SearchCarsSuccess extends MarketState {}
class SearchCarsError extends MarketState {
  final String error;
  SearchCarsError(this.error);
}

// 🔥 حالات الفلتر 🔥
class FilterSelectionChanged extends MarketState {}
class FilterCarsLoading extends MarketState {}
class FilterCarsLoadingMore extends MarketState {}
class FilterCarsSuccess extends MarketState {}

class CarImagePickedSuccess extends MarketState {}
class CarImagePickedError extends MarketState {
  final String error;
  CarImagePickedError(this.error);
}

// 🔥 حالات الحفظ (Saved Cars) والمقارنة (Compare) الجديدة 🔥
class SavedCarsLoading extends MarketState {}
class SavedCarsSuccess extends MarketState {}
class SavedCarsError extends MarketState {
  final String error;
  SavedCarsError(this.error);
}

class CompareCarsUpdated extends MarketState {}