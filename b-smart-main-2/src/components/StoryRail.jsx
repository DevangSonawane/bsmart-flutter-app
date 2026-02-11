import React, { useState } from 'react';
import StoryViewer from './StoryViewer';

const stories = [
  { id: 1, username: 'your_story', isUser: true, imageUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=500&auto=format&fit=crop&q=60' },
  { id: 2, username: 'jane_doe', imageUrl: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=500&auto=format&fit=crop&q=60' },
  { id: 3, username: 'john_smith', imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&auto=format&fit=crop&q=60' },
  { id: 4, username: 'travel_lover', imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500&auto=format&fit=crop&q=60' },
  { id: 5, username: 'foodie_life', imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60' },
  { id: 6, username: 'tech_guru', imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500&auto=format&fit=crop&q=60' },
  { id: 7, username: 'art_daily', imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500&auto=format&fit=crop&q=60' },
];

const StoryRail = () => {
  const [selectedStoryIndex, setSelectedStoryIndex] = useState(null);

  const handleStoryClick = (index) => {
    setSelectedStoryIndex(index);
  };

  return (
    <>
      <div className="bg-white dark:bg-black border-b border-gray-200 dark:border-gray-800 py-4 mb-2">
        <div className="flex gap-4 overflow-x-auto px-4 no-scrollbar">
          {stories.map((story, index) => (
            <button
              key={story.id}
              className="flex flex-col items-center min-w-[70px] cursor-pointer"
              onClick={() => handleStoryClick(index)}
            >
              <div className={`w-16 h-16 rounded-full p-[2px] ${story.isUser ? 'border-2 border-gray-300 dark:border-gray-700' : 'bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink'}`}>
                <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px]">
                  <img
                    src={story.imageUrl || `https://i.pravatar.cc/150?u=${story.username}`}
                    alt={story.username}
                    className="w-full h-full rounded-full object-cover"
                  />
                </div>
              </div>
              <span className="text-xs mt-1 truncate w-full text-center text-gray-700 dark:text-gray-200">
                {story.isUser ? 'Your Story' : story.username}
              </span>
            </button>
          ))}
        </div>
      </div>

      {selectedStoryIndex !== null && (
        <StoryViewer
          initialStoryIndex={selectedStoryIndex}
          stories={stories}
          onClose={() => setSelectedStoryIndex(null)}
        />
      )}
    </>
  );
};

export default StoryRail;
