import React, { useState, useRef, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Home, Megaphone, Clapperboard, Target, Plus, Image, Video } from 'lucide-react';

const BottomNav = ({ onOpenCreateModal }) => {
  const location = useLocation();
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const dropdownRef = useRef(null);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsDropdownOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  return (
    <div className="md:hidden fixed bottom-2 left-0 right-0 flex justify-center z-50">
      <div className="w-full max-w-[95%]">
        <div className="relative">
          <div className="bg-white dark:bg-black px-4 py-4 rounded-full shadow-[0_8px_30px_rgb(0,0,0,0.12)] flex justify-between items-center border border-gray-100 dark:border-gray-800">
            {/* Left Items: Home, Ads */}
            <div className="flex-1 flex justify-around pr-8">
              <Link to="/" className="flex justify-center">
                <div className={`transition-colors ${location.pathname === '/' ? 'text-[#fa3f5e]' : 'text-gray-400 dark:text-gray-500'}`}>
                  <Home size={22} strokeWidth={location.pathname === '/' ? 2.5 : 2} />
                </div>
              </Link>
              <Link to="/ads" className="flex justify-center">
                <div className={`transition-colors ${location.pathname === '/ads' ? 'text-[#fa3f5e]' : 'text-gray-400 dark:text-gray-500'}`}>
                  <Target size={22} strokeWidth={location.pathname === '/ads' ? 2.5 : 2} />
                </div>
              </Link>
            </div>

            {/* Right Items: Promote, Reels */}
            <div className="flex-1 flex justify-around pl-8 gap-2">
              <Link to="/promote" className="flex justify-center">
                <div className={`transition-colors ${location.pathname === '/promote' ? 'text-[#fa3f5e]' : 'text-gray-400 dark:text-gray-500'}`}>
                  <Megaphone size={22} strokeWidth={location.pathname === '/promote' ? 2.5 : 2} />
                </div>
              </Link>
              <Link to="/reels" className="flex justify-center">
                <div className={`transition-colors ${location.pathname === '/reels' ? 'text-[#fa3f5e]' : 'text-gray-400 dark:text-gray-500'}`}>
                  <Clapperboard size={22} strokeWidth={location.pathname === '/reels' ? 2.5 : 2} />
                </div>
              </Link>
            </div>
          </div>

          {/* Center Button: Create */}
          <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2" ref={dropdownRef}>
            <button
              onClick={() => setIsDropdownOpen(!isDropdownOpen)}
              className="w-10 h-10 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center shadow-xl border-[3px] border-gray-50 dark:border-black hover:scale-105 transition-transform"
            >
              <Plus size={20} className={`text-white transition-transform duration-200 ${isDropdownOpen ? 'rotate-45' : ''}`} />
            </button>

            {/* Dropdown Menu */}
            {isDropdownOpen && (
              <div className="absolute bottom-full mb-3 left-1/2 -translate-x-1/2 w-40 bg-white dark:bg-gray-900 rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 overflow-hidden animate-fade-in-up origin-bottom">
                <button
                  onClick={() => {
                    onOpenCreateModal('post');
                    setIsDropdownOpen(false);
                  }}
                  className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200 border-b border-gray-50 dark:border-gray-800"
                >
                  <Image size={18} className="text-insta-purple" />
                  Create Post
                </button>
                <button
                  onClick={() => {
                    onOpenCreateModal('reel');
                    setIsDropdownOpen(false);
                  }}
                  className="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-3 text-sm font-medium text-gray-700 dark:text-gray-200"
                >
                  <Video size={18} className="text-insta-pink" />
                  Upload Reel
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default BottomNav;
