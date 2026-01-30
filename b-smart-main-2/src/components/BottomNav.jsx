import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Home, Megaphone, Clapperboard, Target, Plus } from 'lucide-react';

const BottomNav = () => {
  const location = useLocation();

  return (
    <div className="md:hidden fixed bottom-2 left-0 right-0 flex justify-center z-50">
      <div className="w-full max-w-[95%]">
        <div className="relative">
          <div className="bg-white px-4 py-4 rounded-full shadow-[0_8px_30px_rgb(0,0,0,0.12)] flex justify-between items-center border border-gray-100">
            {/* Left Items: Home, Ads */}
            <div className="flex-1 flex justify-around pr-8">
              <Link to="/" className="flex justify-center">
                <div className={`transition-colors ${location.pathname === '/' ? 'text-[#fa3f5e]' : 'text-gray-400'}`}>
                  <Home size={22} strokeWidth={location.pathname === '/' ? 2.5 : 2} />
                </div>
              </Link>
              <Link to="/ads" className="flex justify-center">
                <div className={`transition-colors ${location.pathname === '/ads' ? 'text-[#fa3f5e]' : 'text-gray-400'}`}>
                  <Target size={22} strokeWidth={location.pathname === '/ads' ? 2.5 : 2} />
                </div>
              </Link>
            </div>

            {/* Right Items: Promote, Reels */}
            <div className="flex-1 flex justify-around pl-8 gap-2">
              <Link to="/promote" className="flex justify-center">
                <div className={`transition-colors ${location.pathname === '/promote' ? 'text-[#fa3f5e]' : 'text-gray-400'}`}>
                  <Megaphone size={22} strokeWidth={location.pathname === '/promote' ? 2.5 : 2} />
                </div>
              </Link>
              <Link to="/reels" className="flex justify-center">
                <div className={`transition-colors ${location.pathname === '/reels' ? 'text-[#fa3f5e]' : 'text-gray-400'}`}>
                  <Clapperboard size={22} strokeWidth={location.pathname === '/reels' ? 2.5 : 2} />
                </div>
              </Link>
            </div>
          </div>

          {/* Center Button: Create */}
          <Link
            to="/create"
            className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-10 h-10 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center shadow-xl border-[3px] border-gray-50 hover:scale-105 transition-transform"
          >
            <Plus size={20} className="text-white" />
          </Link>
        </div>
      </div>
    </div>
  );
};

export default BottomNav;
