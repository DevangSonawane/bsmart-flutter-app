import React, { useEffect } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { supabase } from './lib/supabase';
import { setUser, setLoading } from './store/authSlice';
import Layout from './components/Layout';
import Home from './pages/Home';
import CreatePost from './pages/CreatePost';
import Reels from './pages/Reels';
import Promote from './pages/Promote';
import Ads from './pages/Ads';
import Profile from './pages/Profile';
import Settings from './pages/Settings';
import Login from './pages/Login';
import Signup from './pages/Signup';
import ForgotPassword from './pages/ForgotPassword';
import VerifyOtp from './pages/VerifyOtp';
import EditProfile from './pages/EditProfile';
import ProtectedRoute from './components/ProtectedRoute';

function App() {
  const dispatch = useDispatch();

  useEffect(() => {
    const fetchUserProfile = async (session) => {
      if (session?.user) {
        try {
          const { data: userProfile, error } = await supabase
            .from('users')
            .select('*')
            .eq('id', session.user.id)
            .single();

          let walletData = null;
          try {
            const { data: wallet } = await supabase
              .from('wallets')
              .select('*')
              .eq('user_id', session.user.id)
              .single();
            walletData = wallet;
          } catch (err) {
            console.error('Error fetching wallet:', err);
          }

          if (userProfile) {
            dispatch(setUser({ ...userProfile, auth_email: session.user.email, wallet: walletData }));
          } else {
            // Profile should be created by trigger, but if not found immediately (race condition), use metadata
            // Or just set basic user info
            const metadata = session.user.user_metadata || {};
            dispatch(setUser({
              id: session.user.id,
              email: session.user.email,
              full_name: metadata.full_name,
              username: metadata.username,
              avatar_url: metadata.avatar_url,
              auth_email: session.user.email,
              wallet: walletData
            }));
          }
        } catch (error) {
          console.error('Error fetching profile:', error);
          dispatch(setUser(session.user));
        }
      } else {
        dispatch(setUser(null));
      }
      dispatch(setLoading(false));
    };

    // Check active session
    supabase.auth.getSession().then(({ data: { session } }) => {
      fetchUserProfile(session);
    });

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      fetchUserProfile(session);
    });

    return () => subscription.unsubscribe();
  }, [dispatch]);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/signup" element={<Signup />} />
        <Route path="/forgot-password" element={<ForgotPassword />} />
        <Route path="/verify-otp" element={<VerifyOtp />} />

        <Route path="/" element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }>
          <Route index element={<Home />} />
          <Route path="/create" element={<CreatePost />} />
          <Route path="/reels" element={<Reels />} />
          <Route path="/promote" element={<Promote />} />
          <Route path="/ads" element={<Ads />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="/edit-profile" element={<EditProfile />} />
          <Route path="/settings" element={<Settings />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
