import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/dashboard_remote_data_source.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

class FetchDashboardStatsEvent extends DashboardEvent {}

abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStatsModel stats;

  const DashboardLoaded(this.stats);

  @override
  List<Object?> get props => [stats];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardRemoteDataSource _dataSource;

  DashboardBloc({required DashboardRemoteDataSource dataSource})
      : _dataSource = dataSource,
        super(DashboardInitial()) {
    on<FetchDashboardStatsEvent>(_onFetchStats);
  }

  Future<void> _onFetchStats(
    FetchDashboardStatsEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final stats = await _dataSource.getRealDashboardStats();
      emit(DashboardLoaded(stats));
    } catch (e) {
      emit(DashboardError('Unable to load dashboard metrics. ${e.toString()}'));
    }
  }
}
