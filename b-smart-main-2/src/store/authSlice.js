import { createSlice } from '@reduxjs/toolkit';

const initialState = {
  userObject: null,
  isAuthenticated: false,
  loading: true,
};

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setUser: (state, action) => {
      state.userObject = action.payload;
      state.isAuthenticated = !!action.payload;
      state.loading = false;
    },
    logout: (state) => {
      state.userObject = null;
      state.isAuthenticated = false;
      state.loading = false;
    },
    setLoading: (state, action) => {
      state.loading = action.payload;
    },
  },
});

export const { setUser, logout, setLoading } = authSlice.actions;
export default authSlice.reducer;
