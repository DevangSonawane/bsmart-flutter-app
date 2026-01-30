import React, { useState } from 'react';
import { Heart, MessageCircle, User, Bell, Wallet } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useSelector } from 'react-redux';

const TopBar = () => {
  const [showNotifications, setShowNotifications] = useState(false);
  const { userObject } = useSelector((state) => state.auth);

  return (
    <div className="md:hidden fixed top-0 left-0 right-0 bg-white border-b border-gray-200 px-4 py-3 flex justify-between items-center z-50">
      <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange" style={{ fontFamily: 'cursive' }}>
        b_smart
      </h1>
      <div className="flex gap-4 items-center">
        {/* Wallet Display for Mobile */}
        <div className="flex items-center gap-1 bg-gray-50 px-2 py-1 rounded-full border border-gray-100">
          <div className="w-5 h-5 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-white">
            <Wallet size={12} />
          </div>
          <span className="text-xs font-bold text-gray-900">1,250</span>
        </div>

        {/* Notifications with Dropdown */}
        <div className="relative">
          <button onClick={() => setShowNotifications(!showNotifications)} className="relative">
            <Heart size={24} className="text-black" />
            <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-[#fa3f5e] rounded-full border-2 border-white"></span>
          </button>

          {showNotifications && (
            <div className="absolute right-0 top-full mt-2 w-64 bg-white rounded-xl shadow-xl border border-gray-100 py-2 z-50 animate-fade-in">
              <div className="px-4 py-2 border-b border-gray-50">
                <h3 className="font-semibold text-sm">Notifications</h3>
              </div>
              <div className="max-h-60 overflow-y-auto">
                <div className="px-4 py-3 hover:bg-gray-50 flex gap-3 items-center">
                  <div className="w-8 h-8 rounded-full bg-blue-50 text-blue-500 flex items-center justify-center"><Bell size={14} /></div>
                  <div>
                    <p className="text-xs text-gray-900">New follower: <span className="font-bold">Sarah</span></p>
                    <p className="text-[10px] text-gray-500">2 min ago</p>
                  </div>
                </div>
                <div className="px-4 py-3 hover:bg-gray-50 flex gap-3 items-center">
                  <div className="w-8 h-8 rounded-full bg-pink-50 text-pink-500 flex items-center justify-center"><Heart size={14} /></div>
                  <div>
                    <p className="text-xs text-gray-900">Mike liked your post</p>
                    <p className="text-[10px] text-gray-500">1 hour ago</p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        <MessageCircle size={24} className="text-black" />

        <Link to="/profile">
          <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink p-[1.5px]">
            <div className="w-full h-full rounded-full bg-white p-[1px]">
              <img
                src={userObject?.avatar_url || "https://i.pravatar.cc/150?u=my_profile"}
                alt={userObject?.username || "Profile"}
                className="w-full h-full rounded-full object-cover"
              />
            </div>
          </div>
        </Link>
      </div>
    </div>
  );
};

export default TopBar;
