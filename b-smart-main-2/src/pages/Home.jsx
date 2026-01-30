import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import StoryRail from '../components/StoryRail';
import PostCard from '../components/PostCard';
import PostDetailModal from '../components/PostDetailModal';
import { supabase } from '../lib/supabase';

const Home = () => {
  const navigate = useNavigate();
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedPost, setSelectedPost] = useState(null);

  useEffect(() => {
    const fetchPosts = async () => {
      try {
        const { data, error } = await supabase
          .from('posts')
          .select(`
            *,
            users (
              id,
              username,
              avatar_url
            )
          `)
          .order('created_at', { ascending: false });

        if (error) throw error;
        setPosts(data || []);
      } catch (error) {
        console.error('Error fetching posts:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchPosts();
  }, []);

  const handleCommentClick = (post) => {
    if (window.innerWidth < 768) {
      navigate(`/post/${post.id}`);
    } else {
      setSelectedPost(post);
    }
  };

  return (
    <div>
      <StoryRail />
      <div className="pb-4">
        {loading ? (
          <div className="flex justify-center p-8">
            <div className="animate-spin w-8 h-8 border-2 border-gray-300 dark:border-gray-700 border-t-blue-500 rounded-full"></div>
          </div>
        ) : (
          posts.map(post => (
            <PostCard
              key={post.id}
              post={post}
              onCommentClick={handleCommentClick}
            />
          ))
        )}
      </div>

      {/* Post Detail Modal */}
      <PostDetailModal
        isOpen={!!selectedPost}
        post={selectedPost}
        onClose={() => setSelectedPost(null)}
      />
    </div>
  );
};

export default Home;
