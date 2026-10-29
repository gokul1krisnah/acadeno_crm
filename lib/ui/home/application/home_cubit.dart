import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repository/home_repo.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _repository;
  StreamSubscription? _userSub;

  HomeCubit(this._repository)
    : super(HomeState(user: _repository.currentUserFallback())) {
    _userSub = _repository.watchCurrentUser().listen((user) {
      if (!isClosed) emit(state.copyWith(user: user));
    });
  }

  void selectBottomNav(int index) {
    emit(state.copyWith(bottomNavIndex: index));
  }

  @override
  Future<void> close() {
    _userSub?.cancel();
    return super.close();
  }
}
