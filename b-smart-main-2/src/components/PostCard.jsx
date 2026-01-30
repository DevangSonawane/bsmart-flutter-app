import React, { useState, useEffect } from 'react';
import { Heart, MessageCircle, Send, Bookmark } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useSelector } from 'react-redux';
import { Link } from 'react-router-dom';

const PostCard = ({ post, onCommentClick }) => {
    const { userObject } = useSelector((state) => state.auth);
    const [isLiked, setIsLiked] = useState(false);
    const [likeCount, setLikeCount] = useState(0);
    const [latestComment, setLatestComment] = useState(null);

    useEffect(() => {
        if (post) {
            const likes = post.likes || [];
            // Check if current user is in the likes array
            const userLiked = userObject ? likes.some(like => like.user_id === userObject.id) : false;
            setIsLiked(userLiked);
            setLikeCount(likes.length);

            // Fetch latest comment
            const fetchLatestComment = async () => {
                try {
                    const { data, error } = await supabase
                        .from('comments')
                        .select(`
                            id,
                            content,
                            created_at,
                            users (
                                username
                            )
                        `)
                        .eq('post_id', post.id)
                        .order('created_at', { ascending: false })
                        .limit(1)
                        .single();

                    if (error && error.code !== 'PGRST116') throw error; // PGRST116 is no rows found
                    if (data) {
                        setLatestComment(data);
                    }
                } catch (error) {
                    console.error('Error fetching latest comment:', error);
                }
            };

            fetchLatestComment();
        }
    }, [post, userObject]);

    const handleLike = async () => {
        if (!userObject) return;

        const likes = post.likes || [];
        let newLikes;
        let newIsLiked;

        if (isLiked) {
            // Unlike: Remove user from array
            newLikes = likes.filter(like => like.user_id !== userObject.id);
            newIsLiked = false;
        } else {
            // Like: Add user to array
            newLikes = [...likes, { user_id: userObject.id, like: true }];
            newIsLiked = true;
        }

        // Optimistic update
        setIsLiked(newIsLiked);
        setLikeCount(newLikes.length);

        try {
            const { error } = await supabase
                .from('posts')
                .update({ likes: newLikes })
                .eq('id', post.id);

            if (error) throw error;

            // Update local post object reference if needed by parent
            post.likes = newLikes;
        } catch (error) {
            console.error('Error updating like:', error);
            // Revert
            setIsLiked(!newIsLiked);
            setLikeCount(likes.length);
        }
    };

    // Handle different data structures (Supabase join vs flat)
    const displayImage = post.media?.[0]?.image || post.imageUrl || 'https://via.placeholder.com/600';
    const user = post.users || post.user || {};
    const username = user.username || post.username || 'User';
    const avatar = user.avatar_url || post.userAvatar || 'https://via.placeholder.com/150';
    const userId = user.id || post.user_id;

    return (
        <div className="bg-white dark:bg-black mb-4 border-b border-gray-200 dark:border-gray-800 pb-4 md:rounded-lg md:border max-w-[470px] mx-auto">
            {/* Header */}
            <div className="flex items-center justify-between p-3">
                <div className="flex items-center gap-2">
                    {userId ? (
                        <Link to={`/profile/${userId}`} className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink p-[1.5px] block">
                            <div className="bg-white dark:bg-black rounded-full p-[1.5px] w-full h-full">
                                <img src={avatar} alt={username} className="w-full h-full rounded-full object-cover" />
                            </div>
                        </Link>
                    ) : (
                        <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink p-[1.5px]">
                            <div className="bg-white dark:bg-black rounded-full p-[1.5px] w-full h-full">
                                <img src={avatar} alt={username} className="w-full h-full rounded-full object-cover" />
                            </div>
                        </div>
                    )}
                    {userId ? (
                        <Link to={`/profile/${userId}`} className="font-semibold text-sm hover:underline dark:text-white">{username}</Link>
                    ) : (
                        <span className="font-semibold text-sm dark:text-white">{username}</span>
                    )}
                </div>
                <button className="text-gray-500 dark:text-gray-400">...</button>
            </div>

            {/* Image */}
            <div className="w-full bg-gray-100 dark:bg-[#121212] md:rounded-md overflow-hidden">
                <img src={displayImage} alt="Post" className="w-full h-auto object-cover" />
            </div>

            {/* Actions */}
            <div className="p-3">
                <div className="flex justify-between mb-2">
                    <div className="flex gap-4">
                        <button onClick={handleLike} className="hover:opacity-50 transition-opacity">
                            <Heart size={24} className={isLiked ? 'fill-red-500 text-red-500' : 'text-black dark:text-white'} />
                        </button>
                        <button onClick={() => onCommentClick && onCommentClick(post)} className="hover:opacity-50 transition-opacity">
                            <MessageCircle size={24} className="text-black dark:text-white" />
                        </button>
                    </div>
                    <button className="hover:opacity-50 transition-opacity">
                        <Bookmark size={24} className="text-black dark:text-white" />
                    </button>
                </div>

                <div className="font-semibold text-sm mb-1 dark:text-white">{likeCount} likes</div>

                <div className="text-sm dark:text-white">
                    <span className="font-semibold mr-2 dark:text-white">{username}</span>
                    {post.caption}
                </div>

                {latestComment && (
                    <div className="text-sm mt-1 dark:text-white">
                        <span className="font-semibold mr-2 dark:text-white">{latestComment.users?.username}</span>
                        {latestComment.content}
                    </div>
                )}

                <div className="text-gray-500 dark:text-gray-400 text-xs mt-1 uppercase">
                    {post.created_at ? new Date(post.created_at).toLocaleDateString() : 'Just now'}
                </div>
            </div>
        </div>
    );
};

export default PostCard;