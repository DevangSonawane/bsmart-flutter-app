import React from 'react';
import StoryRail from '../components/StoryRail';
import FeedPost from '../components/FeedPost';

const Home = () => {
  const posts = [
    {
      id: 1,
      username: 'jane_doe',
      userAvatar: 'https://i.pravatar.cc/150?u=jane_doe',
      imageUrl: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&auto=format&fit=crop&q=60',
      likes: 120,
      caption: 'Loving the new outfit! 🌸 #fashion #style'
    },
    {
      id: 2,
      username: 'travel_lover',
      userAvatar: 'https://i.pravatar.cc/150?u=travel_lover',
      imageUrl: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=600&auto=format&fit=crop&q=60',
      likes: 845,
      caption: 'Paris is always a good idea 🗼 #travel #paris'
    },
    {
      id: 3,
      username: 'foodie_life',
      userAvatar: 'https://i.pravatar.cc/150?u=foodie_life',
      imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=60',
      likes: 562,
      caption: 'Best burger in town! 🍔 #foodie #delicious'
    }
  ];

  return (
    <div>
      <StoryRail />
      <div className="pb-4">
        {posts.map(post => (
          <FeedPost key={post.id} post={post} />
        ))}
      </div>
    </div>
  );
};

export default Home;
