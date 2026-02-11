import React, { useState, useEffect } from 'react';
import { Heart, MessageCircle, Send, Bookmark, MoreHorizontal, Edit, Trash2, ChevronLeft, ChevronRight } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useSelector } from 'react-redux';
import { Link } from 'react-router-dom';
import api from '../lib/api';

const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
    if (!isOpen) return null;
    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in p-4">
            <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800 transform transition-all scale-100">
                {isDeleting ? (
                    <div className="flex flex-col items-center justify-center py-8">
                        <div className="animate-spin w-12 h-12 border-4 border-gray-200 border-t-red-500 rounded-full mb-4"></div>
                        <p className="text-gray-500 dark:text-gray-400 font-medium animate-pulse">Deleting post...</p>
                    </div>
                ) : (
                    <>
                        <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">Delete Post?</h3>
                        <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">
                            Are you sure you want to delete this post? This action cannot be undone.
                        </p>
                        <div className="flex gap-3">
                            <button
                                onClick={onClose}
                                className="flex-1 px-4 py-2.5 rounded-lg border border-gray-200 dark:border-gray-700 font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={onConfirm}
                                className="flex-1 px-4 py-2.5 rounded-lg bg-red-500 text-white font-medium hover:bg-red-600 transition-colors shadow-lg shadow-red-500/20"
                            >
                                Delete
                            </button>
                        </div>
                    </>
                )}
            </div>
        </div>
    );
};

const PostCard = ({ post, onCommentClick, onDelete }) => {
    const { userObject } = useSelector((state) => state.auth);
    const [isLiked, setIsLiked] = useState(false);
    const [likeCount, setLikeCount] = useState(0);
    const [latestComment, setLatestComment] = useState(null);
    const [showOptions, setShowOptions] = useState(false);
    const [showDeleteModal, setShowDeleteModal] = useState(false);
    const [isDeleting, setIsDeleting] = useState(false);
    const [currentImageIndex, setCurrentImageIndex] = useState(0);

    // Handle different data structures (Supabase join vs flat vs new API)
    const user = post.user_id || post.users || post.user || {};
    const username = user.username || post.username || 'User';
    // Don't default to placeholder immediately so we can detect missing avatar
    const avatar = user.avatar_url || post.userAvatar;
    const userId = user.id || user._id || post.user_id;

    // Check if current user is the post owner
    const isOwner = userObject && (
        (userObject.id && userId && String(userObject.id) === String(userId)) ||
        (userObject._id && userId && String(userObject._id) === String(userId))
    );

    // Extract media items
    const mediaItems = post.media && post.media.length > 0
        ? post.media
        : (post.imageUrl ? [{ fileUrl: post.imageUrl }] : []);

    const nextImage = (e) => {
        e.stopPropagation();
        setCurrentImageIndex((prev) => (prev === mediaItems.length - 1 ? 0 : prev + 1));
    };

    const prevImage = (e) => {
        e.stopPropagation();
        setCurrentImageIndex((prev) => (prev === 0 ? mediaItems.length - 1 : prev - 1));
    };

    useEffect(() => {
        if (post) {
            // New API structure uses is_liked_by_me and likes_count
            if (typeof post.is_liked_by_me !== 'undefined') {
                setIsLiked(post.is_liked_by_me);
                setLikeCount(post.likes_count || 0);
            } else {
                // Fallback for old structure
                const likes = post.likes || [];
                const userLiked = userObject ? likes.some(like => like.user_id === userObject.id) : false;
                setIsLiked(userLiked);
                setLikeCount(likes.length);
            }

            // New API structure provides comments array
            if (post.comments && post.comments.length > 0) {
                // Assuming comments are sorted or we take the first one
                const comment = post.comments[0];
                setLatestComment({
                    users: comment.user,
                    content: comment.text,
                    id: comment._id
                });
            } else if (!post.comments) {
                // Only fetch if comments are not provided in post object (legacy)
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

                        if (error && error.code !== 'PGRST116') throw error;
                        if (data) {
                            setLatestComment(data);
                        }
                    } catch (error) {
                        console.error('Error fetching latest comment:', error);
                    }
                };

                fetchLatestComment();
            }
        }
    }, [post, userObject]);

    const handleLike = async () => {
        if (!userObject) return;

        const newIsLiked = !isLiked;
        const newLikeCount = newIsLiked ? likeCount + 1 : Math.max(0, likeCount - 1);

        // Optimistic update
        setIsLiked(newIsLiked);
        setLikeCount(newLikeCount);

        try {
            // Determine if we are using new API or old Supabase
            if (post._id) {
                // New API call would go here - for now just optimistic
                // await api.post(`/posts/${post._id}/like`);
            } else {
                const likes = post.likes || [];
                let newLikes;
                if (isLiked) {
                    newLikes = likes.filter(like => like.user_id !== userObject.id);
                } else {
                    newLikes = [...likes, { user_id: userObject.id, like: true }];
                }

                const { error } = await supabase
                    .from('posts')
                    .update({ likes: newLikes })
                    .eq('id', post.id);
                if (error) throw error;
                post.likes = newLikes;
            }
        } catch (error) {
            console.error('Error updating like:', error);
            // Revert
            setIsLiked(!newIsLiked);
            setLikeCount(likeCount);
        }
    };

    const handleDeleteClick = () => {
        setShowOptions(false);
        setShowDeleteModal(true);
    };

    const handleConfirmDelete = async () => {
        setIsDeleting(true);
        try {
            const postId = post._id || post.id;
            const token = localStorage.getItem('token');
            await api.delete(`/posts/${postId}`, {
                headers: {
                    Authorization: `Bearer ${token}` // Attach token to header 
                }
            });
            // Small delay to ensure the loader is seen and transition is smooth
            await new Promise(resolve => setTimeout(resolve, 1500));

            if (onDelete) {
                onDelete(postId);
            }
        } catch (error) {
            console.error('Error deleting post:', error);
            const errorMessage = error.response?.data?.message || 'Failed to delete post';
            alert(errorMessage);
            setIsDeleting(false);
            setShowDeleteModal(false);
        }
    };

    return (
        <div className="bg-white dark:bg-black mb-4 border-b border-gray-200 dark:border-gray-800 pb-4 md:rounded-lg md:border max-w-[470px] mx-auto">
            {/* Header */}
            <div className="flex items-center justify-between p-3 relative">
                <div className="flex items-center gap-2">
                    {userId ? (
                        <Link to={`/profile/${userId}`} className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink p-[1.5px] block">
                            <div className="bg-white dark:bg-black rounded-full p-[1.5px] w-full h-full">
                                {avatar ? (
                                    <img src={avatar} alt={username} className="w-full h-full rounded-full object-cover" />
                                ) : (
                                    <div className="w-full h-full rounded-full bg-gray-200 dark:bg-gray-800 flex items-center justify-center text-xs font-bold text-gray-700 dark:text-gray-300">
                                        {username.charAt(0).toUpperCase()}
                                    </div>
                                )}
                            </div>
                        </Link>
                    ) : (
                        <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink p-[1.5px]">
                            <div className="bg-white dark:bg-black rounded-full p-[1.5px] w-full h-full">
                                {avatar ? (
                                    <img src={avatar} alt={username} className="w-full h-full rounded-full object-cover" />
                                ) : (
                                    <div className="w-full h-full rounded-full bg-gray-200 dark:bg-gray-800 flex items-center justify-center text-xs font-bold text-gray-700 dark:text-gray-300">
                                        {username.charAt(0).toUpperCase()}
                                    </div>
                                )}
                            </div>
                        </div>
                    )}
                    {userId ? (
                        <Link to={`/profile/${userId}`} className="font-semibold text-sm hover:underline dark:text-white">{username}</Link>
                    ) : (
                        <span className="font-semibold text-sm dark:text-white">{username}</span>
                    )}
                </div>

                <div className="relative">
                    {isOwner && (
                        <button
                            onClick={() => setShowOptions(!showOptions)}
                            className="text-gray-500 dark:text-gray-400 p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
                        >
                            <MoreHorizontal size={20} />
                        </button>
                    )}

                    {showOptions && isOwner && (
                        <div className="absolute right-0 top-full mt-1 w-48 bg-white dark:bg-[#262626] rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-1 z-50 animate-fade-in">
                            <button
                                className="w-full px-4 py-2.5 text-left text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-2 transition-colors"
                                onClick={() => {
                                    // Handle edit logic here later
                                    setShowOptions(false);
                                    alert('Edit functionality coming soon');
                                }}
                            >
                                <Edit size={16} />
                                <span>Edit Post</span>
                            </button>
                            <button
                                className="w-full px-4 py-2.5 text-left text-sm text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 flex items-center gap-2 transition-colors border-t border-gray-50 dark:border-gray-800"
                                onClick={handleDeleteClick}
                            >
                                <Trash2 size={16} />
                                <span>Delete Post</span>
                            </button>
                        </div>
                    )}
                </div>
            </div>

            <DeleteModal
                isOpen={showDeleteModal}
                onClose={() => setShowDeleteModal(false)}
                onConfirm={handleConfirmDelete}
                isDeleting={isDeleting}
            />

            {/* Image Swiper */}
            <div className="w-full bg-gray-100 dark:bg-[#121212] md:rounded-md overflow-hidden min-h-[300px] relative group">
                {mediaItems.length > 0 ? (
                    <>
                        <div className="w-full h-auto min-h-[300px] flex items-center justify-center bg-black">
                            <img
                                src={mediaItems[currentImageIndex].fileUrl || mediaItems[currentImageIndex].image}
                                alt={`Post content ${currentImageIndex + 1}`}
                                className="w-full h-auto max-h-[600px] object-contain"
                            />
                        </div>

                        {/* Navigation Arrows */}
                        {mediaItems.length > 1 && (
                            <>
                                <button
                                    onClick={prevImage}
                                    className="absolute left-2 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-1.5 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                                >
                                    <ChevronLeft size={20} />
                                </button>
                                <button
                                    onClick={nextImage}
                                    className="absolute right-2 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-1.5 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                                >
                                    <ChevronRight size={20} />
                                </button>

                                {/* Dots Pagination */}
                                <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5">
                                    {mediaItems.map((_, idx) => (
                                        <div
                                            key={idx}
                                            className={`w-2 h-2 rounded-full transition-all duration-300 ${idx === currentImageIndex
                                                    ? 'bg-white scale-110'
                                                    : 'bg-white/50'
                                                }`}
                                        />
                                    ))}
                                </div>
                            </>
                        )}
                    </>
                ) : (
                    <div className="flex flex-col items-center justify-center p-8 text-gray-500 dark:text-gray-400">
                        <div className="text-sm font-medium">Post unavailable</div>
                    </div>
                )}
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