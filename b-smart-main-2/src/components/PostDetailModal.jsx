import React, { useState, useEffect } from 'react';
import { X, Heart, MessageCircle, Send, Bookmark, MoreHorizontal, Smile } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useSelector } from 'react-redux';

const PostDetailModal = ({ post, isOpen, onClose }) => {
    const { userObject } = useSelector((state) => state.auth);
    const [comments, setComments] = useState([]);
    const [newComment, setNewComment] = useState('');
    const [isLoadingComments, setIsLoadingComments] = useState(false);
    const [isLiked, setIsLiked] = useState(false);
    const [likeCount, setLikeCount] = useState(0);
    const [postUser, setPostUser] = useState(null);

    useEffect(() => {
        if (isOpen && post) {
            fetchComments();
            fetchPostUser();
            // Reset states
            setNewComment('');

            const likes = post.likes || [];
            const userLiked = userObject ? likes.some(like => like.user_id === userObject.id) : false;
            setIsLiked(userLiked);
            setLikeCount(likes.length);
        }
    }, [isOpen, post, userObject]);

    const fetchPostUser = async () => {
        if (!post?.user_id) return;
        try {
            const { data, error } = await supabase
                .from('users')
                .select('*')
                .eq('id', post.user_id)
                .single();

            if (error) throw error;
            setPostUser(data);
        } catch (error) {
            console.error('Error fetching post user:', error);
        }
    };

    const fetchComments = async () => {
        setIsLoadingComments(true);
        try {
            const { data, error } = await supabase
                .from('comments')
                .select(`
                    *,
                    user:users (
                        id,
                        username,
                        avatar_url
                    )
                `)
                .eq('post_id', post.id)
                .order('created_at', { ascending: true });

            if (error) throw error;
            setComments(data || []);
        } catch (error) {
            console.error('Error fetching comments:', error);
        } finally {
            setIsLoadingComments(false);
        }
    };

    const handlePostComment = async (e) => {
        e.preventDefault();
        if (!newComment.trim() || !userObject) return;

        try {
            const { error } = await supabase
                .from('comments')
                .insert({
                    post_id: post.id,
                    user_id: userObject.id,
                    content: newComment.trim()
                });

            if (error) throw error;

            setNewComment('');
            fetchComments(); // Refresh comments
        } catch (error) {
            console.error('Error posting comment:', error);
        }
    };

    const handleLike = async () => {
        if (!userObject) return;

        const likes = post.likes || [];
        let newLikes;
        let newIsLiked;

        if (isLiked) {
            newLikes = likes.filter(like => like.user_id !== userObject.id);
            newIsLiked = false;
        } else {
            newLikes = [...likes, { user_id: userObject.id, like: true }];
            newIsLiked = true;
        }

        setIsLiked(newIsLiked);
        setLikeCount(newLikes.length);

        try {
            const { error } = await supabase
                .from('posts')
                .update({ likes: newLikes })
                .eq('id', post.id);

            if (error) throw error;

            // Update local post reference (mutate)
            post.likes = newLikes;
        } catch (error) {
            console.error('Error updating like count:', error);
            // Revert on error
            setIsLiked(!newIsLiked);
            setLikeCount(likes.length);
        }
    };

    if (!isOpen || !post) return null;

    // Format date relative (simple version)
    const formatDate = (dateString) => {
        const date = new Date(dateString);
        const now = new Date();
        const diffInSeconds = Math.floor((now - date) / 1000);

        if (diffInSeconds < 60) return `${diffInSeconds}s`;
        if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m`;
        if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h`;
        if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d`;
        return `${Math.floor(diffInSeconds / 604800)}w`;
    };

    const displayImage = post.media?.[0]?.image || 'https://via.placeholder.com/600';

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 md:p-10">
            <button
                onClick={onClose}
                className="absolute top-4 right-4 text-white hover:opacity-75 z-60"
            >
                <X size={24} />
            </button>

            <div className="bg-white dark:bg-black max-w-[90vw] md:max-w-[1200px] w-full max-h-[90vh] h-full md:h-[85vh] flex flex-col md:flex-row overflow-hidden rounded-md md:rounded-r-xl animate-in fade-in zoom-in duration-200">
                {/* Left Side - Image */}
                <div className="bg-black flex items-center justify-center w-full md:w-[55%] h-[40vh] md:h-full">
                    <img
                        src={displayImage}
                        alt="Post content"
                        className="max-w-full max-h-full object-contain"
                    />
                </div>

                {/* Right Side - Details */}
                <div className="flex flex-col w-full md:w-[45%] h-full bg-white dark:bg-black">
                    {/* Header */}
                    <div className="flex items-center justify-between p-3 md:p-4 border-b border-gray-100 dark:border-gray-800 shrink-0">
                        <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-800 overflow-hidden">
                                <img
                                    src={postUser?.avatar_url || 'https://via.placeholder.com/150'}
                                    alt={postUser?.username}
                                    className="w-full h-full object-cover"
                                />
                            </div>
                            <div className="flex flex-col">
                                <span className="font-semibold text-sm text-gray-900 dark:text-white hover:opacity-70 cursor-pointer">
                                    {postUser?.username || 'User'}
                                </span>
                                {post.location && (
                                    <span className="text-xs text-gray-500 dark:text-gray-400">{post.location}</span>
                                )}
                            </div>
                        </div>
                        <button className="text-gray-900 dark:text-white hover:opacity-50">
                            <MoreHorizontal size={20} />
                        </button>
                    </div>

                    {/* Comments & Caption Scroll Area */}
                    <div className="flex-1 overflow-y-auto p-3 md:p-4 scrollbar-hide">
                        {/* Caption */}
                        <div className="flex gap-3 mb-4">
                            <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-800 overflow-hidden shrink-0">
                                <img
                                    src={postUser?.avatar_url || 'https://via.placeholder.com/150'}
                                    alt={postUser?.username}
                                    className="w-full h-full object-cover"
                                />
                            </div>
                            <div className="flex-1 text-sm">
                                <span className="font-semibold mr-2 dark:text-white">{postUser?.username}</span>
                                <span className="text-gray-900 dark:text-gray-100 whitespace-pre-wrap">{post.caption}</span>
                                <div className="text-gray-500 dark:text-gray-400 text-xs mt-1">
                                    {formatDate(post.created_at)}
                                </div>
                            </div>
                        </div>

                        {/* Comments List */}
                        {isLoadingComments ? (
                            <div className="flex justify-center py-4">
                                <div className="animate-spin w-6 h-6 border-2 border-gray-300 dark:border-gray-700 border-t-blue-500 rounded-full"></div>
                            </div>
                        ) : comments.length > 0 ? (
                            comments.map((comment) => (
                                <div key={comment.id} className="flex gap-3 mb-4">
                                    <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-800 overflow-hidden shrink-0">
                                        <img
                                            src={comment.user?.avatar_url || 'https://via.placeholder.com/150'}
                                            alt={comment.user?.username}
                                            className="w-full h-full object-cover"
                                        />
                                    </div>
                                    <div className="flex-1 text-sm group">
                                        <div className="flex justify-between items-start">
                                            <div>
                                                <span className="font-semibold mr-2 dark:text-white">{comment.user?.username}</span>
                                                <span className="text-gray-900 dark:text-gray-100">{comment.content}</span>
                                                <div className="text-gray-500 dark:text-gray-400 text-xs mt-1 flex gap-3">
                                                    <span>{formatDate(comment.created_at)}</span>
                                                    {/* <button className="font-semibold hover:text-gray-900">Reply</button> */}
                                                </div>
                                            </div>
                                            <button className="text-gray-400 dark:text-gray-600 hover:text-gray-600 dark:hover:text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity">
                                                <Heart size={12} />
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            ))
                        ) : (
                            <div className="text-center text-gray-500 dark:text-gray-400 text-sm py-4">
                                No comments yet.
                            </div>
                        )}
                    </div>

                    {/* Actions & Input Footer */}
                    <div className="border-t border-gray-100 dark:border-gray-800 bg-white dark:bg-black shrink-0">
                        <div className="p-3 md:p-4 pb-2">
                            <div className="flex justify-between mb-2">
                                <div className="flex gap-4">
                                    <button
                                        onClick={handleLike}
                                        className="hover:opacity-50 transition-opacity"
                                    >
                                        <Heart
                                            size={24}
                                            className={isLiked ? 'fill-red-500 text-red-500' : 'text-gray-900 dark:text-white'}
                                        />
                                    </button>
                                    <button className="hover:opacity-50 transition-opacity">
                                        <MessageCircle size={24} className="text-gray-900 dark:text-white" />
                                    </button>
                                    <button className="hover:opacity-50 transition-opacity">
                                        <Send size={24} className="text-gray-900 dark:text-white" />
                                    </button>
                                </div>
                                <button className="hover:opacity-50 transition-opacity">
                                    <Bookmark size={24} className="text-gray-900 dark:text-white" />
                                </button>
                            </div>
                            <div className="font-semibold text-sm text-gray-900 dark:text-white mb-1">
                                {likeCount} likes
                            </div>
                            <div className="text-[10px] text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                                {new Date(post.created_at).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}
                            </div>
                        </div>

                        {/* Input Area */}
                        <form onSubmit={handlePostComment} className="border-t border-gray-100 dark:border-gray-800 p-3 md:p-4 flex items-center gap-3">
                            <button type="button" className="text-gray-900 dark:text-white hover:opacity-50">
                                <Smile size={24} />
                            </button>
                            <input
                                type="text"
                                placeholder="Add a comment..."
                                className="flex-1 text-sm outline-none text-gray-900 dark:text-white bg-transparent placeholder-gray-500 dark:placeholder-gray-400"
                                value={newComment}
                                onChange={(e) => setNewComment(e.target.value)}
                            />
                            <button
                                type="submit"
                                disabled={!newComment.trim()}
                                className={`text-blue-500 font-semibold text-sm ${!newComment.trim() ? 'opacity-50' : 'hover:text-blue-700'}`}
                            >
                                Post
                            </button>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default PostDetailModal;
