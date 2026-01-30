import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { supabase } from '../lib/supabase';
import { logout } from '../store/authSlice';
import {
  ArrowLeft,
  Globe2,
  Bell,
  Shield,
  Lock,
  SlidersHorizontal,
  Info,
  HelpCircle,
  ChevronRight,
  LogOut,
  Loader2
} from 'lucide-react';

const settingsSections = [
  {
    title: 'Preferences',
    items: [
      {
        icon: Globe2,
        label: 'Language / Region',
        subLabel: 'Default: English',
      },
      {
        icon: Bell,
        label: 'Notifications',
        subLabel: 'Manage notifications',
      },
    ],
  },
  {
    title: 'Account',
    items: [
      {
        icon: Shield,
        label: 'Privacy',
        subLabel: 'Privacy settings',
      },
      {
        icon: Lock,
        label: 'Security',
        subLabel: 'Password, 2FA',
      },
      {
        icon: SlidersHorizontal,
        label: 'Content Settings',
        subLabel: 'Moderation & restrictions',
      },
    ],
  },
  {
    title: 'About',
    items: [
      {
        icon: Info,
        label: 'About b Smart',
        subLabel: 'Version 1.0.0',
      },
      {
        icon: HelpCircle,
        label: 'Help & Support',
        subLabel: 'Contact support',
      },
    ],
  },
];

const Settings = () => {
  const navigate = useNavigate();
  const dispatch = useDispatch();
  const [loggingOut, setLoggingOut] = useState(false);

  const handleLogout = async () => {
    try {
      setLoggingOut(true);
      await supabase.auth.signOut();
      dispatch(logout());
      navigate('/login');
    } catch (error) {
      console.error('Error logging out:', error);
    } finally {
      setLoggingOut(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      <div className="sticky top-0 bg-white border-b border-gray-200 px-4 py-3 flex justify-between items-center z-40">
        <Link to="/profile" className="text-gray-800">
          <ArrowLeft size={24} />
        </Link>
        <h1 className="text-lg font-semibold">Settings</h1>
        <div className="w-6" />
      </div>

      <div className="max-w-2xl mx-auto pt-4 px-4">
        {settingsSections.map((section) => (
          <div key={section.title} className="mb-6">
            <h2 className="text-xs font-semibold text-[#fa3f5e] mb-2 uppercase tracking-wide">
              {section.title}
            </h2>

            <div className="space-y-3">
              {section.items.map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    key={item.label}
                    className="w-full flex items-center justify-between p-4 bg-white border border-gray-100 rounded-2xl shadow-sm hover:bg-gray-50 transition-colors text-left"
                  >
                    <div className="flex items-center gap-4">
                      <div className="w-10 h-10 rounded-full bg-pink-50 flex items-center justify-center text-[#fa3f5e]">
                        <Icon size={20} strokeWidth={2.5} />
                      </div>
                      <div className="flex flex-col">
                        <span className="font-medium text-gray-900">
                          {item.label}
                        </span>
                        {item.subLabel && (
                          <span className="text-xs text-gray-500">
                            {item.subLabel}
                          </span>
                        )}
                      </div>
                    </div>
                    <ChevronRight size={18} className="text-gray-400" />
                  </button>
                );
              })}
            </div>
          </div>
        ))}

        {/* Logout Section */}
        <div className="mb-6">
          <h2 className="text-xs font-semibold text-[#fa3f5e] mb-2 uppercase tracking-wide">
            Actions
          </h2>
          <button
            onClick={handleLogout}
            disabled={loggingOut}
            className="w-full flex items-center justify-between p-4 bg-white border border-gray-100 rounded-2xl shadow-sm hover:bg-red-50 transition-colors text-left group"
          >
            <div className="flex items-center gap-4">
              <div className="w-10 h-10 rounded-full bg-red-50 flex items-center justify-center text-red-500 group-hover:bg-red-100 transition-colors">
                {loggingOut ? <Loader2 size={20} className="animate-spin" /> : <LogOut size={20} strokeWidth={2.5} />}
              </div>
              <div className="flex flex-col">
                <span className="font-medium text-red-600">
                  {loggingOut ? 'Logging out...' : 'Log Out'}
                </span>
                <span className="text-xs text-gray-500">
                  Sign out of your account
                </span>
              </div>
            </div>
          </button>
        </div>
      </div>
    </div>
  );
};

export default Settings;

