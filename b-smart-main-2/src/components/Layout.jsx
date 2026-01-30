import React, { useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import BottomNav from './BottomNav';
import TopBar from './TopBar';
import Sidebar from './Sidebar';
import { Heart, Bell, MessageCircle } from 'lucide-react';

const Layout = () => {
  const location = useLocation();
  const isExcludedPage = ['/profile', '/settings', '/reels', '/promote'].includes(location.pathname);
  const isFullScreenPage = ['/reels', '/promote'].includes(location.pathname);
  // Show TopBar on mobile for all pages except profile, settings, reels, and promote
  const showTopBar = !isExcludedPage;
  const [showDesktopNotifications, setShowDesktopNotifications] = useState(false);

  return (
    <div className={`min-h-screen bg-gray-50 md:pb-0 ${isFullScreenPage ? 'pb-0' : 'pb-16'}`}>
      <Sidebar />

      <div className="md:pl-20 min-h-screen transition-all duration-300">
        {showTopBar && <TopBar />}

        {/* Main Content Container with Gaps on Desktop */}
        <div className={`
          ${showTopBar ? 'pt-16 md:pt-4' : 'pt-0 md:pt-4'} 
          w-full 
          md:max-w-[calc(100%-80px)] 
          lg:max-w-4xl 
          mx-auto 
          px-0 
          md:px-8
        `}>
          <Outlet />
        </div>
      </div>

      <BottomNav />

      {/* Desktop Top Right Notifications */}
      {!isExcludedPage && (
        <div
          className="hidden md:block fixed top-8 right-8 z-50"
          onMouseEnter={() => setShowDesktopNotifications(true)}
          onMouseLeave={() => setShowDesktopNotifications(false)}
        >
          <button
            className="w-10 h-10 rounded-full bg-white shadow-lg border border-gray-100 flex items-center justify-center hover:bg-gray-50 transition-colors relative"
            onClick={() => setShowDesktopNotifications(!showDesktopNotifications)}
          >
            <Heart size={20} className="text-gray-900" />
            <span className="absolute top-2 right-2.5 w-2 h-2 bg-[#fa3f5e] rounded-full border border-white"></span>
          </button>

          {showDesktopNotifications && (
            <div className="absolute right-0 top-full pt-2 w-80 z-50 animate-fade-in">
              <div className="bg-white rounded-xl shadow-xl border border-gray-100 py-2">
                <div className="px-4 py-3 border-b border-gray-50 flex justify-between items-center">
                  <h3 className="font-semibold text-sm">Notifications</h3>
                  <span className="text-xs text-[#fa3f5e] font-medium cursor-pointer">Mark all read</span>
                </div>
                <div className="max-h-80 overflow-y-auto">
                  <div className="px-4 py-3 hover:bg-gray-50 flex gap-3 items-center cursor-pointer transition-colors">
                    <div className="w-8 h-8 rounded-full bg-blue-50 text-blue-500 flex items-center justify-center flex-shrink-0"><Bell size={14} /></div>
                    <div>
                      <p className="text-sm text-gray-900">New follower: <span className="font-bold">Sarah</span></p>
                      <p className="text-xs text-gray-500">2 min ago</p>
                    </div>
                  </div>
                  <div className="px-4 py-3 hover:bg-gray-50 flex gap-3 items-center cursor-pointer transition-colors">
                    <div className="w-8 h-8 rounded-full bg-pink-50 text-pink-500 flex items-center justify-center flex-shrink-0"><Heart size={14} /></div>
                    <div>
                      <p className="text-sm text-gray-900">Mike liked your post</p>
                      <p className="text-xs text-gray-500">1 hour ago</p>
                    </div>
                  </div>
                  <div className="px-4 py-3 hover:bg-gray-50 flex gap-3 items-center cursor-pointer transition-colors">
                    <div className="w-8 h-8 rounded-full bg-purple-50 text-purple-500 flex items-center justify-center flex-shrink-0"><MessageCircle size={14} /></div>
                    <div>
                      <p className="text-sm text-gray-900">Anna commented: "Amazing!"</p>
                      <p className="text-xs text-gray-500">2 hours ago</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Floating Wallet for Desktop */}
      {!isExcludedPage && (
        <div className="hidden md:flex fixed bottom-8 right-8 z-50 bg-white rounded-full shadow-lg p-1 pr-4 items-center gap-2 border border-gray-100 animate-fade-in hover:scale-105 transition-transform cursor-pointer">
          <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12V7H5a2 2 0 0 1 0-4h14v4" /><path d="M3 5v14a2 2 0 0 0 2 2h16v-5" /><path d="M18 12a2 2 0 0 0 0 4h4v-4Z" /></svg>
          </div>
          <div className="flex flex-col">
            <span className="text-xs text-gray-500 font-medium">Balance</span>
            <span className="text-sm font-bold text-gray-900">1,250</span>
          </div>
        </div>
      )}
    </div>
  );
};

export default Layout;
