import React, { useState } from 'react';
import { Heart, MessageCircle, Send, Bookmark } from 'lucide-react';

const FeedPost = ({ post }) => {
  const [liked, setLiked] = useState(false);

  return (
    <div className="bg-white mb-4 border-b border-gray-200 pb-4 md:rounded-lg md:border max-w-[470px] mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between p-3">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink p-[1.5px]">
            <div className="bg-white rounded-full p-[1.5px] w-full h-full">
              <img src={post.userAvatar} alt={post.username} className="w-full h-full rounded-full object-cover" />
            </div>
          </div>
          <span className="font-semibold text-sm">{post.username}</span>
        </div>
        <button className="text-gray-500">...</button>
      </div>

      {/* Image */}
      <div className="w-full aspect-[4/5] bg-gray-100 md:rounded-md overflow-hidden">
        <img src={post.imageUrl} alt="Post" className="w-full h-full object-cover" />
      </div>

      {/* Actions */}
      <div className="p-3">
        <div className="flex justify-between mb-2">
          <div className="flex gap-4">
            <button onClick={() => setLiked(!liked)}>
              <Heart size={24} className={liked ? 'fill-red-500 text-red-500' : 'text-black'} />
            </button>
            <button>
              <MessageCircle size={24} className="text-black" />
            </button>
            <button>
              <Send size={24} className="text-black" />
            </button>
          </div>
          <button>
            <Bookmark size={24} className="text-black" />
          </button>
        </div>

        <div className="font-semibold text-sm mb-1">{post.likes} likes</div>

        <div className="text-sm">
          <span className="font-semibold mr-2">{post.username}</span>
          {post.caption}
        </div>

        <div className="text-gray-500 text-xs mt-1 uppercase">2 hours ago</div>
      </div>
    </div>
  );
};

export default FeedPost;
