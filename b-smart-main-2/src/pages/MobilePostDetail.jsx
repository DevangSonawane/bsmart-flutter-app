import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useSelector } from 'react-redux';
import { ArrowLeft, MoreHorizontal, Heart, MessageCircle, Send, Bookmark, Smile } from 'lucide-react';

const MobilePostDetail = () => {
  const { postId } = useParams();
  const navigate = useNavigate();
  const { userObject } = useSelector((state) => state.auth);

  const [post, setPost] = useState(null);
  const [postUser, setPostUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [isLiked, setIsLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);
  const [commentCount, setCommentCount] = useState(0);
  const [isBookmarked, setIsBookmarked] = useState(false);

  useEffect(() => {
    fetchPostDetails();
  }, [postId]);

  const fetchPostDetails = async () => {
    try {
      setLoading(true);

      // Fetch post
      const { data: postData, error: postError } = await supabase
        .from('posts')
        .select('*')
        .eq('id', postId)
        .single();

      if (postError) throw postError;
      setPost(postData);

      const likes = postData.likes || [];
      const userLiked = userObject ? likes.some(like => like.user_id === userObject.id) : false;
      setIsLiked(userLiked);
      setLikeCount(likes.length);

      // Fetch post user
      if (postData.user_id) {
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('*')
          .eq('id', postData.user_id)
          .single();

        if (userError) throw userError;
        setPostUser(userData);
      }

      // Fetch comment count
      const { count, error: commentError } = await supabase
        .from('comments')
        .select('*', { count: 'exact', head: true })
        .eq('post_id', postId);

      if (!commentError) {
        setCommentCount(count || 0);
      }

      // Check if liked by current user (mock implementation for now as we don't have a likes table yet)
      // In a real app, we would query a 'likes' table
      // const { data: likeData } = await supabase.from('likes').select('*').eq('post_id', postId).eq('user_id', userObject?.id).single();
      // setIsLiked(!!likeData);

    } catch (error) {
      console.error('Error fetching post details:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleLike = async () => {
    if (!userObject) return;

    const likes = post.likes || [];
    let newLikes;
    let newIsLiked;

    if (isLiked) {
      // Unlike
      newLikes = likes.filter(like => like.user_id !== userObject.id);
      newIsLiked = false;
    } else {
      // Like
      newLikes = [...likes, { user_id: userObject.id, like: true }];
      newIsLiked = true;
    }

    setIsLiked(newIsLiked);
    setLikeCount(newLikes.length);

    // Update in DB
    try {
      const { error } = await supabase
        .from('posts')
        .update({ likes: newLikes })
        .eq('id', postId);

      if (error) {
        console.error('Error updating like count:', error);
        throw error;
      }

      // Update local post object
      setPost({ ...post, likes: newLikes });
    } catch (error) {
      console.error('Error handling like:', error);
      // Revert on error
      setIsLiked(!newIsLiked);
      setLikeCount(likes.length);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 dark:border-white"></div>
      </div>
    );
  }

  if (!post) {
    return (
      <div className="min-h-screen bg-white dark:bg-black flex flex-col items-center justify-center p-4">
        <p className="text-gray-500 mb-4">Post not found</p>
        <button onClick={() => navigate(-1)} className="text-blue-500 font-semibold">Go Back</button>
      </div>
    );
  }

  const mediaList = post.media || [];
  const currentMedia = mediaList[currentImageIndex];

  return (
    <div className="min-h-screen bg-white dark:bg-black pb-20">
      {/* Top Bar */}
      <div className="sticky top-0 bg-white dark:bg-black z-50 px-4 py-3 flex items-center justify-between border-b border-gray-100 dark:border-gray-800">
        <button onClick={() => navigate(-1)} className="text-gray-900 dark:text-white">
          <ArrowLeft size={24} />
        </button>
        <h1 className="text-lg font-bold text-gray-900 dark:text-white">Post</h1>
        <div className="w-6"></div> {/* Spacer for centering */}
      </div>

      {/* User Header */}
      <div className="px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full p-[2px] bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink">
            <div className="w-full h-full rounded-full bg-white dark:bg-black p-[2px] overflow-hidden">
              <img
                src={postUser?.avatar_url || 'https://via.placeholder.com/150'}
                alt={postUser?.username}
                className="w-full h-full rounded-full object-cover"
              />
            </div>
          </div>
          <div className="flex flex-col">
            <span className="font-semibold text-sm text-gray-900 dark:text-white leading-tight">
              {postUser?.username || 'User'}
            </span>
            {post.location && (
              <span className="text-xs text-gray-500 dark:text-gray-400 leading-tight">{post.location}</span>
            )}
          </div>
        </div>
        <button className="text-gray-900 dark:text-white">
          <MoreHorizontal size={20} />
        </button>
      </div>

      {/* Image/Media */}
      <div className="w-full bg-gray-100 dark:bg-gray-900 relative">
        <div className="aspect-[4/5] w-full relative overflow-hidden">
          <img
            src={currentMedia?.image || 'https://via.placeholder.com/600'}
            alt="Post content"
            className="w-full h-full object-cover"
          />
        </div>

        {/* Carousel Indicators */}
        {mediaList.length > 1 && (
          <div className="absolute bottom-4 left-0 right-0 flex justify-center gap-1.5">
            {mediaList.map((_, idx) => (
              <div
                key={idx}
                className={`w-1.5 h-1.5 rounded-full transition-colors ${idx === currentImageIndex ? 'bg-white' : 'bg-white/50'}`}
              />
            ))}
          </div>
        )}
      </div>

      {/* Actions */}
      <div className="px-4 py-3">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-4">
            <button onClick={handleLike} className="flex items-center gap-1.5 group">
              <Heart
                size={26}
                className={`transition-colors ${isLiked ? 'fill-red-500 text-red-500' : 'text-gray-900 dark:text-white group-hover:text-gray-600 dark:group-hover:text-gray-300'}`}
              />
              {likeCount > 0 && (
                <span className="font-semibold text-sm text-gray-900 dark:text-white">{likeCount}</span>
              )}
            </button>

            <button className="flex items-center gap-1.5 group">
              <MessageCircle size={26} className="text-gray-900 dark:text-white group-hover:text-gray-600 dark:group-hover:text-gray-300 flip-horizontal" />
              {commentCount > 0 && (
                <span className="font-semibold text-sm text-gray-900 dark:text-white">{commentCount}</span>
              )}
            </button>

            <button className="text-gray-900 dark:text-white hover:text-gray-600 dark:hover:text-gray-300">
              <Send size={26} />
            </button>
          </div>

          <button onClick={() => setIsBookmarked(!isBookmarked)} className="text-gray-900 dark:text-white hover:text-gray-600 dark:hover:text-gray-300">
            <Bookmark size={26} className={isBookmarked ? 'fill-black text-black dark:fill-white dark:text-white' : ''} />
          </button>
        </div>

        {/* Caption */}
        <div className="space-y-1">
          <div className="text-sm text-gray-900 dark:text-white">
            <span className="font-semibold mr-2">{postUser?.username}</span>
            {post.caption}
          </div>
          <div className="text-[10px] text-gray-500 dark:text-gray-400 uppercase tracking-wide pt-1">
            {new Date(post.created_at).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}
          </div>
        </div>
      </div>

      {/* Comment Input Preview (Optional, matching typical mobile UI) */}
      <div className="px-4 py-3 flex items-center gap-3 border-t border-gray-50 dark:border-gray-800 mt-2">
        <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-700 overflow-hidden shrink-0">
          <img
            src={userObject?.avatar_url || 'https://via.placeholder.com/150'}
            alt="My Avatar"
            className="w-full h-full object-cover"
          />
        </div>
        <div className="flex-1 text-gray-400 text-sm">Add a comment...</div>
        <div className="text-xl">😍</div>
        <div className="text-xl">😂</div>
      </div>
    </div>
  );
};

export default MobilePostDetail;
