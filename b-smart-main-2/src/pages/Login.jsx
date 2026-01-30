import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { supabase } from '../lib/supabase';
import { ArrowLeft, Mail, Lock, User, Phone, LogIn, AlertCircle, CheckCircle } from 'lucide-react';

const Login = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { isAuthenticated } = useSelector((state) => state.auth);
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState(location.state?.message || '');

  useEffect(() => {
    if (isAuthenticated) {
      navigate('/');
    }
  }, [isAuthenticated, navigate]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');
    setLoading(true);

    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: identifier,
        password
      });
      if (signInError) throw signInError;
      // Navigation is handled by useEffect on isAuthenticated
    } catch (err) {
      if (err.message === 'Email not confirmed') {
        setError('Please verify your email address. Check your inbox for the confirmation link.');
      } else {
        setError(err.message || 'Login failed');
      }
      setLoading(false);
    }
  };

  const handleGoogleLogin = async () => {
    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: `${window.location.origin}/`,
        },
      });
      if (error) throw error;
    } catch (err) {
      setError(err.message || 'Google login failed');
    }
  };

  return (
    <div className="min-h-screen flex bg-white">
      {/* Left Side - Visuals (Hidden on mobile) */}
      <div className="hidden lg:flex lg:w-1/2 relative bg-insta-gradient overflow-hidden">
        <div className="absolute inset-0 bg-black/10" />
        <div className="absolute inset-0 flex flex-col items-center justify-center text-white p-12 text-center z-10">
          <div className="w-24 h-24 bg-white/20 backdrop-blur-lg rounded-3xl flex items-center justify-center mb-8 shadow-xl border border-white/30">
            <LogIn size={48} className="text-white" />
          </div>
          <h1 className="text-4xl font-bold mb-4 tracking-tight">Welcome Back!</h1>
          <p className="text-lg text-white/90 max-w-md font-light leading-relaxed">
            Connect with friends, share your moments, and discover new experiences with b_smart.
          </p>

          {/* Decorative circles */}
          <div className="absolute -top-24 -left-24 w-64 h-64 bg-white/10 rounded-full blur-3xl" />
          <div className="absolute -bottom-32 -right-32 w-80 h-80 bg-purple-900/20 rounded-full blur-3xl" />
        </div>
      </div>

      {/* Right Side - Form */}
      <div className="w-full lg:w-1/2 flex flex-col justify-center px-6 sm:px-12 xl:px-24 bg-white">
        <div className="max-w-md w-full mx-auto">
          <div className="mb-8">
            <Link to="/" className="inline-flex items-center text-gray-500 hover:text-insta-pink transition-colors mb-6 group">
              <ArrowLeft size={20} className="mr-2 group-hover:-translate-x-1 transition-transform" />
              Back to Home
            </Link>
            <h2 className="text-3xl font-bold text-gray-900 mb-2">Log In</h2>
            <p className="text-gray-500">Enter your credentials to access your account.</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="space-y-1">
              <label className="text-sm font-medium text-gray-700 ml-1">Identity</label>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 group-focus-within:text-insta-pink transition-colors">
                  <User size={20} />
                </div>
                <input
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                  placeholder="Email, Phone, or Username"
                  className="w-full pl-10 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400"
                  required
                />
              </div>
            </div>

            <div className="space-y-1">
              <div className="flex justify-between items-center ml-1">
                <label className="text-sm font-medium text-gray-700">Password</label>
                <Link to="/forgot-password" className="text-xs font-medium text-insta-pink hover:text-insta-purple transition-colors">Forgot password?</Link>
              </div>
              <div className="relative group">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 group-focus-within:text-insta-pink transition-colors">
                  <Lock size={20} />
                </div>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full pl-10 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink transition-all placeholder:text-gray-400"
                  required
                />
              </div>
            </div>

            {message && (
              <div className="p-3 rounded-lg bg-green-50 border border-green-100 text-green-600 text-sm flex items-center">
                <CheckCircle className="w-4 h-4 mr-2 flex-shrink-0" />
                {message}
              </div>
            )}

            {error && (
              <div className="p-3 rounded-lg bg-red-50 border border-red-100 text-red-600 text-sm flex items-center">
                <AlertCircle className="w-4 h-4 mr-2 flex-shrink-0" />
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white py-3.5 rounded-xl font-bold shadow-lg shadow-insta-pink/30 hover:shadow-xl hover:shadow-insta-pink/40 hover:scale-[1.02] active:scale-[0.98] transition-all disabled:opacity-70 disabled:hover:scale-100 disabled:shadow-none"
            >
              {loading ? (
                <span className="flex items-center justify-center">
                  <svg className="animate-spin -ml-1 mr-2 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Signing in...
                </span>
              ) : 'Sign In'}
            </button>
          </form>

          <div className="relative my-8">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-gray-200"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-4 bg-white text-gray-500 font-medium">Or continue with</span>
            </div>
          </div>

          <button
            onClick={handleGoogleLogin}
            type="button"
            className="w-full flex items-center justify-center gap-3 bg-white border border-gray-200 text-gray-700 py-3.5 rounded-xl font-semibold hover:bg-gray-50 hover:border-gray-300 transition-all shadow-sm hover:shadow"
          >
            <svg className="w-5 h-5" viewBox="0 0 24 24">
              <path
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                fill="#4285F4"
              />
              <path
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                fill="#34A853"
              />
              <path
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                fill="#FBBC05"
              />
              <path
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                fill="#EA4335"
              />
            </svg>
            Continue with Google
          </button>

          <div className="text-center mt-8">
            <p className="text-gray-600">
              Don't have an account?{' '}
              <Link to="/signup" className="text-insta-pink font-semibold hover:text-insta-purple transition-colors">
                Sign up
              </Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
