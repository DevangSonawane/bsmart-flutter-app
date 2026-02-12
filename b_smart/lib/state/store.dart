import 'package:redux/redux.dart';
import 'app_state.dart';
import 'auth_reducer.dart';
import 'profile_reducer.dart';
import 'reels_reducer.dart';
import 'ads_reducer.dart';
import 'feed_reducer.dart';

class AppReducers {
  static AppState reducer(AppState state, dynamic action) {
    return state.copyWith(
      authState: authReducer(state.authState, action),
      profileState: profileReducer(state.profileState, action),
      reelsState: reelsReducer(state.reelsState, action),
      adsState: adsReducer(state.adsState, action),
      feedState: feedReducer(state.feedState, action),
    );
  }
}

Store<AppState> createStore() {
  return Store<AppState>(
    AppReducers.reducer,
    initialState: AppState.initial(),
    middleware: [],
  );
}
