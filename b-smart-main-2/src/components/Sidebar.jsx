import React, { useState, useEffect, useRef } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Home, PlusSquare, Clapperboard, ShoppingBag, User, Menu, Image, Video, Target, Megaphone } from 'lucide-react';
import CreatePostModal from './CreatePostModal';

const Sidebar = () => {
  const location = useLocation();
  const [isHovered, setIsHovered] = useState(false);
  const [isCreateDropdownOpen, setIsCreateDropdownOpen] = useState(false);
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const dropdownRef = useRef(null);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsCreateDropdownOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const navItems = [
    { icon: Home, label: 'Home', path: '/' },
    { icon: Target, label: 'Ads', path: '/ads' },
    { icon: PlusSquare, label: 'Create', path: null, action: () => setIsCreateDropdownOpen(!isCreateDropdownOpen) },
    { icon: Megaphone, label: 'Promote', path: '/promote' },
    { icon: Clapperboard, label: 'Reels', path: '/reels' },
    { icon: User, label: 'Profile', path: '/profile' },
  ];

  return (
    <>
      <div
        className={`hidden md:flex flex-col fixed left-0 top-0 h-full bg-white border-r border-gray-200 z-50 transition-all duration-300 ease-in-out ${isHovered ? 'w-64' : 'w-20'}`}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
      >
        <div className="p-6 mb-2">
          {isHovered ? (
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white font-bold text-lg shadow-md">
                b
              </div>
              <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange transition-opacity duration-300" style={{ fontFamily: 'cursive' }}>
                B-Smart
              </h1>
            </div>
          ) : (
            <div className="w-10 h-10 rounded-lg bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white font-bold text-xl shadow-md transition-transform hover:scale-105">
              b
            </div>
          )}
        </div>

        <div className="flex-1 flex flex-col gap-2 px-3">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path || (item.label === 'Create' && isCreateDropdownOpen);

            if (item.label === 'Create') {
              return (
                <div key={item.label} className="relative" ref={dropdownRef}>
                  <button
                    onClick={item.action}
                    className={`group w-full flex items-center gap-4 p-3 rounded-lg transition-colors duration-200 ${isActive ? 'bg-gradient-to-r from-insta-purple/10 to-insta-orange/10' : 'hover:bg-gray-50'}`}
                  >
                    <div className="min-w-[24px]">
                      <Icon
                        size={24}
                        className={`${isActive ? 'text-[#fa3f5e]' : 'text-gray-900'} transition-transform duration-150 group-hover:scale-110 group-hover:text-black`}
                        strokeWidth={isActive ? 2.5 : 2}
                      />
                    </div>
                    <span
                      className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 group-hover:text-black ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${isActive ? 'text-[#fa3f5e] font-bold' : ''}`}
                    >
                      {item.label}
                    </span>
                  </button>

                  {/* Dropdown Menu */}
                  {isCreateDropdownOpen && (
                    <div className={`absolute left-0 top-full mt-2 w-48 bg-white rounded-lg shadow-lg border border-gray-100 py-2 z-[60] overflow-hidden ${isHovered ? 'translate-x-0' : 'translate-x-14'}`}>
                      <button
                        onClick={() => {
                          setIsCreateModalOpen(true);
                          setIsCreateDropdownOpen(false);
                        }}
                        className="w-full text-left px-4 py-3 hover:bg-gray-50 flex items-center gap-3 text-sm font-medium text-gray-700"
                      >
                        <Image size={18} />
                        Create Post
                      </button>
                      <button
                        onClick={() => {
                          setIsCreateModalOpen(true);
                          setIsCreateDropdownOpen(false);
                        }}
                        className="w-full text-left px-4 py-3 hover:bg-gray-50 flex items-center gap-3 text-sm font-medium text-gray-700"
                      >
                        <Video size={18} />
                        Upload Reel
                      </button>
                    </div>
                  )}
                </div>
              );
            }

            return (
              <Link
                key={item.label}
                to={item.path}
                className={`group flex items-center gap-4 p-3 rounded-xl transition-all duration-200 ${isActive ? 'bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white shadow-md' : 'hover:bg-gray-50 text-gray-900'}`}
              >
                <div className="min-w-[24px]">
                  <Icon
                    size={24}
                    className={`${isActive ? 'text-white' : 'text-gray-900'} transition-transform duration-150 group-hover:scale-110 ${!isActive && 'group-hover:text-black'}`}
                    strokeWidth={isActive ? 2.5 : 2}
                  />
                </div>
                <span
                  className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 ${!isActive && 'group-hover:text-black'} ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'} ${isActive ? 'text-white font-bold' : ''}`}
                >
                  {item.label}
                </span>
              </Link>
            );
          })}

          {/* Extra items commonly found in sidebar */}
          <div className={`mt-auto pb-4`}>
            <Link
              to="#"
              className="group flex items-center gap-4 p-3 rounded-xl hover:bg-gray-50 transition-colors"
            >
              <div className="min-w-[24px]">
                <Menu size={24} className="text-gray-900 transition-transform duration-150 group-hover:scale-110 group-hover:text-black" />
              </div>
              <span
                className={`text-base font-medium whitespace-nowrap overflow-hidden transition-all duration-300 group-hover:text-black ${isHovered ? 'opacity-100 w-auto' : 'opacity-0 w-0'}`}
              >
                More
              </span>
            </Link>
          </div>
        </div>
      </div>

      <CreatePostModal isOpen={isCreateModalOpen} onClose={() => setIsCreateModalOpen(false)} />
    </>
  );
};

export default Sidebar;
