import 'package:redux/redux.dart';
import 'profile_state.dart';
import 'profile_actions.dart';

final profileReducer = combineReducers<ProfileState>([
  TypedReducer<ProfileState, SetProfile>(_setProfile),
  TypedReducer<ProfileState, ClearProfile>(_clearProfile),
]);

ProfileState _setProfile(ProfileState state, SetProfile action) {
  return state.copyWith(profile: action.profile);
}

ProfileState _clearProfile(ProfileState state, ClearProfile action) {
  return ProfileState.initial();
}

