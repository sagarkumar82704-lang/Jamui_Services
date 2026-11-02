import 'package:equatable/equatable.dart';

abstract class DiscoveryEvent extends Equatable {
  const DiscoveryEvent();

  @override
  List<Object?> get props => [];
}

class LoadDiscoveryDataEvent extends DiscoveryEvent {
  final double? customerLatitude;
  final double? customerLongitude;
  final String? customerAreaName;

  const LoadDiscoveryDataEvent({
    this.customerLatitude,
    this.customerLongitude,
    this.customerAreaName,
  });

  @override
  List<Object?> get props => [customerLatitude, customerLongitude, customerAreaName];
}

class UpdateCustomerLocationEvent extends DiscoveryEvent {
  final double latitude;
  final double longitude;
  final String areaName;

  const UpdateCustomerLocationEvent({
    required this.latitude,
    required this.longitude,
    required this.areaName,
  });

  @override
  List<Object?> get props => [latitude, longitude, areaName];
}

class SelectCategoryFilterEvent extends DiscoveryEvent {
  final String categoryId;
  const SelectCategoryFilterEvent(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class SelectAreaFilterEvent extends DiscoveryEvent {
  final String area;
  const SelectAreaFilterEvent(this.area);

  @override
  List<Object?> get props => [area];
}

class SearchProvidersEvent extends DiscoveryEvent {
  final String query;
  const SearchProvidersEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class LoadMoreProvidersEvent extends DiscoveryEvent {
  const LoadMoreProvidersEvent();
}

class ApplyAISearchIntentEvent extends DiscoveryEvent {
  final String query;
  final dynamic intent;

  const ApplyAISearchIntentEvent({
    required this.query,
    required this.intent,
  });

  @override
  List<Object?> get props => [query, intent];
}

class TrackProviderLeadEvent extends DiscoveryEvent {
  final String providerId;
  final bool isCall;
  final String? customerId;
  final String? categoryId;

  const TrackProviderLeadEvent({
    required this.providerId,
    required this.isCall,
    this.customerId,
    this.categoryId,
  });

  @override
  List<Object?> get props => [providerId, isCall, customerId, categoryId];
}

class TrackProviderViewEvent extends DiscoveryEvent {
  final String providerId;
  final String? customerId;

  const TrackProviderViewEvent({
    required this.providerId,
    this.customerId,
  });

  @override
  List<Object?> get props => [providerId, customerId];
}
