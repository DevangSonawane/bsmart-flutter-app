import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Home, Target, Clapperboard, Plus, Megaphone, Image, Video } from 'lucide-react';

const BottomNav = ({ onOpenCreateModal }) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const location = useLocation();
  // userObject is available if needed, but we are following the 5-icon layout request
  // const { userObject } = useSelector((state) => state.auth);

  const isActive = (path) => location.pathname === path;

  // Active color: #fa3f5e (insta-pink-ish) to match the "red outline" description
  const activeColor = "text-[#fa3f5e]";
  const inactiveColor = "text-gray-500 dark:text-gray-400";

  const handleCreateClick = () => {
    setIsMenuOpen(!isMenuOpen);
  };

  const handleOptionClick = (type) => {
    onOpenCreateModal(type);
    setIsMenuOpen(false);
  };

  return (
    <div className="md:hidden fixed bottom-0 left-0 right-0 bg-white dark:bg-black border-t border-gray-200 dark:border-gray-800 flex justify-between items-center px-6 h-[60px] z-50 pb-2">
      <Link to="/" className={`${isActive('/') ? activeColor : inactiveColor}`}>
        <Home size={28} strokeWidth={isActive('/') ? 2.5 : 2} />
      </Link>

      <Link to="/ads" className={`${isActive('/ads') ? activeColor : inactiveColor}`}>
        <Target size={28} strokeWidth={isActive('/ads') ? 2.5 : 2} />
      </Link>

      <div className="relative -top-6 flex flex-col items-center">
        {/* Create Menu */}
        {isMenuOpen && (
          <div className="absolute bottom-16 mb-2 bg-white dark:bg-gray-800 rounded-xl shadow-xl p-2 w-48 flex flex-col gap-1 border border-gray-100 dark:border-gray-700 animate-in fade-in zoom-in duration-200">
            <button
              onClick={() => handleOptionClick('post')}
              className="flex items-center gap-3 w-full p-3 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg transition-colors text-left"
            >
              <Image size={20} className="text-purple-600" />
              <span className="font-semibold text-gray-700 dark:text-gray-200">Create Post</span>
            </button>
            <div className="h-px bg-gray-100 dark:bg-gray-700 mx-2" />
            <button
              onClick={() => handleOptionClick('reel')}
              className="flex items-center gap-3 w-full p-3 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg transition-colors text-left"
            >
              <Video size={20} className="text-pink-600" />
              <span className="font-semibold text-gray-700 dark:text-gray-200">Upload Reel</span>
            </button>
          </div>
        )}

        <button
          onClick={handleCreateClick}
          className="w-14 h-14 rounded-full bg-gradient-to-tr from-[#f09433] via-[#dc2743] to-[#bc1888] flex items-center justify-center shadow-lg border-4 border-white dark:border-black text-white transform transition-transform active:scale-95"
        >
          <Plus
            size={32}
            strokeWidth={3}
            className={`transition-transform duration-300 ${isMenuOpen ? 'rotate-45' : 'rotate-0'}`}
          />
        </button>
      </div>

      <Link to="/promote" className={`${isActive('/promote') ? activeColor : inactiveColor}`}>
        <Megaphone size={28} strokeWidth={isActive('/promote') ? 2.5 : 2} />
      </Link>

      <Link to="/reels" className={`${isActive('/reels') ? activeColor : inactiveColor}`}>
        <Clapperboard size={28} strokeWidth={isActive('/reels') ? 2.5 : 2} />
      </Link>
    </div>
  );
};

export default BottomNav;
