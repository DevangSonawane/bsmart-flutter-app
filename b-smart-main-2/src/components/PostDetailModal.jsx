import React, { useState, useEffect } from 'react';
import { X, Heart, MessageCircle, Send, Bookmark, MoreHorizontal, Smile, ChevronLeft, ChevronRight, Trash2, Edit } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useSelector } from 'react-redux';
import api from '../lib/api';
import commentService from '../services/commentService';

const DeleteModal = ({ isOpen, onClose, onConfirm, isDeleting }) => {
    if (!isOpen) return null;
    return (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in p-4">
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

const PostDetailModal = ({ post: initialPost, isOpen, onClose }) => {
    const { userObject } = useSelector((state) => state.auth);
    const [post, setPost] = useState(initialPost);
    const [comments, setComments] = useState([]);
    const [replies, setReplies] = useState({}); // Map of commentId -> replies array
    const [expandedComments, setExpandedComments] = useState({});
    const [replyTo, setReplyTo] = useState(null); // { id, username }
    const [newComment, setNewComment] = useState('');
    const [isLoadingComments, setIsLoadingComments] = useState(false);
    const [isLiked, setIsLiked] = useState(false);
    const [likeCount, setLikeCount] = useState(0);
    const [postUser, setPostUser] = useState(null);
    const [currentImageIndex, setCurrentImageIndex] = useState(0);
    const [showOptions, setShowOptions] = useState(false);
    const [showDeleteModal, setShowDeleteModal] = useState(false);
    const [isDeleting, setIsDeleting] = useState(false);

    // Check if current user is the post owner
    const isPostOwner = userObject && post && (
        (userObject.id && (post.user_id || post.user?.id) && String(userObject.id) === String(post.user_id || post.user?.id)) ||
        (userObject._id && (post.user_id || post.user?._id) && String(userObject._id) === String(post.user_id || post.user?._id))
    );

    useEffect(() => {
        if (isOpen && initialPost) {
            setPost(initialPost); // Reset to initial post
            setCurrentImageIndex(0); // Reset image index
            fetchPostDetails();
            // Reset states
            setNewComment('');
            setReplyTo(null);
            setReplies({});
        }
    }, [isOpen, initialPost]);

    // Update local state when post data changes
    useEffect(() => {
        if (post) {
            // Check for likes array first
            if (post.likes && Array.isArray(post.likes)) {
                const userId = userObject ? (userObject._id || userObject.id) : null;
                const userLiked = userId ? post.likes.some(like => {
                    // Handle string IDs
                    if (typeof like === 'string') return String(like) === String(userId);
                    // Handle object IDs
                    const likeId = like.user_id || like._id || like.id;
                    const likeUserId = like.user ? (like.user._id || like.user.id) : null;
                    return String(likeId) === String(userId) || String(likeUserId) === String(userId);
                }) : false;

                setIsLiked(userLiked);
                setLikeCount(post.likes.length);
            } else if (typeof post.is_liked_by_me !== 'undefined') {
                setIsLiked(post.is_liked_by_me);
                setLikeCount(post.likes_count || 0);
            } else {
                const likes = post.likes || [];
                const userLiked = userObject ? likes.some(like => like.user_id === userObject.id) : false;
                setIsLiked(userLiked);
                setLikeCount(likes.length);
            }
        }
    }, [post, userObject]);

    const fetchPostDetails = async () => {
        setIsLoadingComments(true);
        try {
            const postId = initialPost._id || initialPost.id;
            const response = await api.get(`/posts/${postId}`);
            const fullPost = response.data;

            setPost(fullPost);

            // Fetch comments using service
            await fetchComments(postId);

            // Handle user
            const user = fullPost.user || fullPost.users || fullPost.user_id;
            if (typeof user === 'object') {
                setPostUser(user);
            } else {
                const { data } = await supabase
                    .from('users')
                    .select('*')
                    .eq('id', user)
                    .single();
                setPostUser(data);
            }

        } catch (error) {
            console.error('Error fetching post details:', error);
            fetchLegacyDetails();
        } finally {
            setIsLoadingComments(false);
        }
    };

    const fetchComments = async (postId = null) => {
        try {
            const id = postId || post._id || post.id;
            const data = await commentService.getComments(id);
            setComments(data || []);

            // Fetch replies for all comments to check for nested content
            if (data && Array.isArray(data)) {
                data.forEach(comment => {
                    const commentId = comment._id || comment.id;
                    commentService.getReplies(commentId)
                        .then(repliesData => {
                            if (repliesData && repliesData.length > 0) {
                                setReplies(prev => ({ ...prev, [commentId]: repliesData }));
                            }
                        })
                        .catch(err => console.error('Error auto-loading replies:', err));
                });
            }
        } catch (error) {
            console.error('Error fetching comments:', error);
        }
    };

    const loadReplies = async (commentId) => {
        try {
            const data = await commentService.getReplies(commentId);
            setReplies(prev => ({ ...prev, [commentId]: data }));
        } catch (error) {
            console.error('Error loading replies:', error);
        }
    };

    const handleLikeComment = async (commentId, isLikedByMe) => {
        try {
            if (isLikedByMe) {
                await commentService.unlikeComment(commentId);
            } else {
                await commentService.likeComment(commentId);
            }
            // Refresh to update counts/status
            fetchComments();
            // If it's a reply, refresh replies
            Object.keys(replies).forEach(key => loadReplies(key));
        } catch (error) {
            console.error('Error liking comment:', error);
        }
    };

    const fetchLegacyDetails = async () => {
        if (!initialPost?.user_id) return;

        try {
            const { data } = await supabase
                .from('users')
                .select('*')
                .eq('id', initialPost.user_id)
                .single();
            setPostUser(data);
        } catch (e) { console.error(e); }

        try {
            const { data } = await supabase
                .from('comments')
                .select(`*, user:users(id, username, avatar_url)`)
                .eq('post_id', initialPost.id)
                .order('created_at', { ascending: true });
            setComments(data || []);
        } catch (e) { console.error(e); }
    };

    const handlePostComment = async (e) => {
        e.preventDefault();
        if (!newComment.trim() || !userObject) return;

        try {
            const postId = post._id || post.id;
            const parentId = replyTo ? replyTo.id : null;

            await commentService.createComment(postId, newComment.trim(), parentId);

            setNewComment('');

            // Refresh comments
            await fetchComments(postId);

            // If replied to a comment, refresh its replies and ensure expanded
            if (replyTo) {
                await loadReplies(replyTo.id);
                setExpandedComments(prev => ({ ...prev, [replyTo.id]: true }));
                setReplyTo(null);
            }
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
            newLikes = likes.filter(like => {
                const likeId = like.user_id || like._id || like.id;
                const userId = userObject._id || userObject.id;
                return String(likeId) !== String(userId);
            });
            newIsLiked = false;
        } else {
            newLikes = [...likes, { user_id: userObject.id || userObject._id, like: true }];
            newIsLiked = true;
        }

        setIsLiked(newIsLiked);
        setLikeCount(newLikes.length);

        try {
            if (post._id) {
                if (newIsLiked) {
                    await api.post(`/posts/${post._id}/like`);
                } else {
                    await api.post(`/posts/${post._id}/unlike`);
                }
            } else {
                const { error } = await supabase
                    .from('posts')
                    .update({ likes: newLikes })
                    .eq('id', post.id);

                if (error) throw error;
            }

            // Update local post reference
            const updatedPost = { ...post, likes: newLikes };
            if (typeof post.is_liked_by_me !== 'undefined') {
                updatedPost.is_liked_by_me = newIsLiked;
                updatedPost.likes_count = newLikes.length;
            }
            setPost(updatedPost);

        } catch (error) {
            console.error('Error updating like count:', error);
            // Revert on error
            setIsLiked(!newIsLiked);
            setLikeCount(likes.length);
        }
    };

    const handleDeletePost = async () => {
        setIsDeleting(true);
        try {
            const id = post._id || post.id;
            const token = localStorage.getItem('token');
            await api.delete(`/posts/${id}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            // Wait a bit
            await new Promise(resolve => setTimeout(resolve, 1000));
            onClose(); // Close modal
            window.location.reload(); // Refresh to update list
        } catch (error) {
            console.error('Error deleting post:', error);
            alert('Failed to delete post');
            setIsDeleting(false);
            setShowDeleteModal(false);
        }
    };

    if (!isOpen || !post) return null;

    // Format date relative (simple version)
    const formatDate = (dateString) => {
        if (!dateString) return '';
        const date = new Date(dateString);
        if (isNaN(date.getTime())) return '';

        const now = new Date();
        const diffInSeconds = Math.floor((now - date) / 1000);

        if (diffInSeconds < 60) return `${Math.max(0, diffInSeconds)}s`;
        if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m`;
        if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h`;
        if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d`;
        return `${Math.floor(diffInSeconds / 604800)}w`;
    };

    const handleDeleteComment = async (commentId) => {
        if (!window.confirm('Are you sure you want to delete this comment?')) return;
        try {
            await api.delete(`/comments/${commentId}`);
            await fetchComments();
        } catch (error) {
            console.error('Error deleting comment:', error);
        }
    };

    const renderComment = (comment, isReply = false) => {
        const commentId = comment._id || comment.id;
        const user = comment.user || comment.users;
        const userId = userObject ? (userObject._id || userObject.id) : null;

        // Check if liked by me
        const isLikedByMe = comment.is_liked_by_me || (comment.likes && Array.isArray(comment.likes) && comment.likes.some(l => {
            if (!userId) return false;
            if (typeof l === 'string') return l === userId;
            return (l.user_id || l._id || l.id) === userId;
        }));

        const likesCount = comment.likes_count || (comment.likes ? comment.likes.length : 0);

        // Check for replies
        const hasReplies = comment.reply_count > 0 || (replies[commentId] && replies[commentId].length > 0) || (comment.replies && comment.replies.length > 0);

        const isOwner = userId && (
            (user && (String(user._id) === String(userId) || String(user.id) === String(userId))) ||
            (comment.user_id && String(comment.user_id) === String(userId))
        );

        return (
            <div key={commentId} className={`flex gap-3 mb-4 ${isReply ? 'ml-12' : ''}`}>
                <div className="w-8 h-8 rounded-full bg-gray-200 dark:bg-gray-800 overflow-hidden shrink-0">
                    {user?.avatar_url ? (
                        <img
                            src={user.avatar_url}
                            alt={user?.username}
                            className="w-full h-full object-cover"
                        />
                    ) : (
                        <div className="w-full h-full flex items-center justify-center text-xs font-bold text-gray-700 dark:text-gray-300">
                            {user?.username ? user.username.charAt(0).toUpperCase() : 'U'}
                        </div>
                    )}
                </div>
                <div className="flex-1 text-sm group">
                    <div className="flex justify-between items-start">
                        <div>
                            <span className="font-semibold mr-2 dark:text-white">{user?.username}</span>
                            <span className="text-gray-900 dark:text-gray-100">{comment.text || comment.content}</span>
                            <div className="text-gray-500 dark:text-gray-400 text-xs mt-1 flex gap-3 items-center">
                                <span>{formatDate(comment.createdAt || comment.created_at)}</span>
                                {likesCount > 0 && <span>{likesCount} likes</span>}
                                <button
                                    className="font-semibold hover:text-gray-900 dark:hover:text-gray-300"
                                    onClick={() => setReplyTo({ id: commentId, username: user?.username })}
                                >
                                    Reply
                                </button>
                            </div>
                        </div>
                        <div className="flex items-center gap-2">
                            <button
                                onClick={() => handleLikeComment(commentId, isLikedByMe)}
                                className={`${isLikedByMe ? 'text-red-500' : 'text-gray-400 dark:text-gray-600 hover:text-gray-600 dark:hover:text-gray-400'} transition-colors flex items-center gap-1`}
                            >
                                <Heart size={12} fill={isLikedByMe ? "currentColor" : "none"} />
                            </button>
                            {isOwner && (
                                <button
                                    onClick={() => handleDeleteComment(commentId)}
                                    className="text-gray-400 dark:text-gray-600 hover:text-red-500 dark:hover:text-red-400 transition-colors"
                                    title="Delete comment"
                                >
                                    <Trash2 size={12} />
                                </button>
                            )}
                        </div>
                    </div>

                    {/* View Replies Button */}
                    {!isReply && hasReplies && (
                        <div className="mt-2">
                            <button
                                className="text-xs text-gray-500 flex items-center gap-2 hover:text-gray-900 dark:hover:text-gray-300"
                                onClick={() => {
                                    if (!replies[commentId] && !comment.replies) {
                                        loadReplies(commentId);
                                    }
                                    setExpandedComments(prev => ({ ...prev, [commentId]: !prev[commentId] }));
                                }}
                            >
                                <div className="w-8 h-[1px] bg-gray-300"></div>
                                {expandedComments[commentId] ? 'Hide replies' : `View replies (${comment.reply_count || (comment.replies ? comment.replies.length : 0) || (replies[commentId] ? replies[commentId].length : '')})`}
                            </button>
                        </div>
                    )}

                    {/* Render Replies */}
                    {!isReply && expandedComments[commentId] && (replies[commentId] || comment.replies) && (
                        <div className="mt-2">
                            {(replies[commentId] || comment.replies).map(reply => renderComment(reply, true))}
                        </div>
                    )}
                </div>
            </div>
        );
    };

    // Prepare media items
    const mediaItems = post.media && post.media.length > 0
        ? post.media
        : (post.imageUrl ? [{ fileUrl: post.imageUrl, type: 'image' }] : []);

    const nextImage = (e) => {
        e.stopPropagation();
        setCurrentImageIndex((prev) => (prev === mediaItems.length - 1 ? 0 : prev + 1));
    };

    const prevImage = (e) => {
        e.stopPropagation();
        setCurrentImageIndex((prev) => (prev === 0 ? mediaItems.length - 1 : prev - 1));
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 md:p-10">
            <button
                onClick={onClose}
                className="absolute top-4 right-4 text-white hover:opacity-75 z-60"
            >
                <X size={24} />
            </button>

            <div className="bg-white dark:bg-black max-w-[90vw] md:max-w-[1200px] w-full max-h-[90vh] h-full md:h-[85vh] flex flex-col md:flex-row overflow-hidden rounded-md md:rounded-r-xl animate-in fade-in zoom-in duration-200">
                {/* Left Side - Image Swiper */}
                <div className="bg-black flex items-center justify-center w-full md:w-[55%] h-[40vh] md:h-full relative group">
                    {mediaItems.length > 0 ? (
                        <>
                            {mediaItems[currentImageIndex].type === 'video' ? (
                                <video
                                    src={mediaItems[currentImageIndex].fileUrl || mediaItems[currentImageIndex].url}
                                    className="w-full h-full object-cover"
                                    controls
                                    autoPlay
                                    loop
                                    muted
                                />
                            ) : (
                                <img
                                    src={mediaItems[currentImageIndex].fileUrl || mediaItems[currentImageIndex].url || mediaItems[currentImageIndex].image}
                                    alt={`Post content ${currentImageIndex + 1}`}
                                    className="w-full h-full object-cover"
                                />
                            )}

                            {/* Navigation Arrows */}
                            {mediaItems.length > 1 && (
                                <>
                                    <button
                                        onClick={prevImage}
                                        className="absolute left-4 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-2 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                                    >
                                        <ChevronLeft size={24} />
                                    </button>
                                    <button
                                        onClick={nextImage}
                                        className="absolute right-4 top-1/2 -translate-y-1/2 bg-black/50 hover:bg-black/70 text-white p-2 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                                    >
                                        <ChevronRight size={24} />
                                    </button>

                                    {/* Dots Pagination */}
                                    <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-1.5">
                                        {mediaItems.map((_, idx) => (
                                            <div
                                                key={idx}
                                                className={`w-2 h-2 rounded-full transition-all duration-300 ${idx === currentImageIndex ? 'bg-white scale-110' : 'bg-white/50'
                                                    }`}
                                            />
                                        ))}
                                    </div>
                                </>
                            )}
                        </>
                    ) : (
                        <div className="text-gray-500">No media available</div>
                    )}
                </div>

                {/* Right Side - Details */}
                <div className="flex flex-col w-full md:w-[45%] h-full bg-white dark:bg-black">
                    {/* Header */}
                    <div className="flex items-center justify-between p-3 md:p-4 border-b border-gray-100 dark:border-gray-800 shrink-0">
                        <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink p-[1.5px]">
                                <div className="bg-white dark:bg-black rounded-full p-[1.5px] w-full h-full">
                                    {postUser?.avatar_url ? (
                                        <img
                                            src={postUser.avatar_url}
                                            alt={postUser?.username}
                                            className="w-full h-full rounded-full object-cover"
                                        />
                                    ) : (
                                        <div className="w-full h-full rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-xs font-bold text-white">
                                            {postUser?.username ? postUser.username.charAt(0).toUpperCase() : 'U'}
                                        </div>
                                    )}
                                </div>
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
                        <div className="relative">
                            {isPostOwner && (
                                <button
                                    onClick={() => setShowOptions(!showOptions)}
                                    className="text-gray-900 dark:text-white hover:opacity-50 p-1 rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
                                >
                                    <MoreHorizontal size={20} />
                                </button>
                            )}

                            {showOptions && isPostOwner && (
                                <div className="absolute right-0 top-full mt-1 w-48 bg-white dark:bg-[#262626] rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-1 z-50 animate-fade-in">
                                    <button
                                        className="w-full px-4 py-2.5 text-left text-sm text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 flex items-center gap-2 transition-colors"
                                        onClick={() => {
                                            setShowOptions(false);
                                            alert('Edit functionality coming soon');
                                        }}
                                    >
                                        <Edit size={16} />
                                        <span>Edit Post</span>
                                    </button>
                                    <button
                                        className="w-full px-4 py-2.5 text-left text-sm text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 flex items-center gap-2 transition-colors border-t border-gray-50 dark:border-gray-800"
                                        onClick={() => {
                                            setShowOptions(false);
                                            setShowDeleteModal(true);
                                        }}
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
                        onConfirm={handleDeletePost}
                        isDeleting={isDeleting}
                    />

                    {/* Comments & Caption Scroll Area */}
                    <div className="flex-1 overflow-y-auto p-3 md:p-4 scrollbar-hide">
                        {/* Caption */}
                        <div className="flex gap-3 mb-4">
                            <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink p-[1.5px] shrink-0">
                                <div className="bg-white dark:bg-black rounded-full p-[1.5px] w-full h-full">
                                    {postUser?.avatar_url ? (
                                        <img
                                            src={postUser.avatar_url}
                                            alt={postUser?.username}
                                            className="w-full h-full rounded-full object-cover"
                                        />
                                    ) : (
                                        <div className="w-full h-full rounded-full bg-gradient-to-tr from-insta-yellow via-insta-orange to-insta-pink flex items-center justify-center text-xs font-bold text-white">
                                            {postUser?.username ? postUser.username.charAt(0).toUpperCase() : 'U'}
                                        </div>
                                    )}
                                </div>
                            </div>
                            <div className="flex-1 text-sm">
                                <span className="font-semibold mr-2 dark:text-white">{postUser?.username}</span>
                                {post.caption ? (
                                    <span className="text-gray-900 dark:text-gray-100 whitespace-pre-wrap">{post.caption}</span>
                                ) : (
                                    <span className="text-gray-500 dark:text-gray-400 italic">No caption</span>
                                )}
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
                            comments.map((comment) => renderComment(comment))
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
                                {(() => {
                                    const dateStr = post.createdAt || post.created_at;
                                    if (!dateStr) return '';
                                    const date = new Date(dateStr);
                                    return isNaN(date.getTime())
                                        ? ''
                                        : date.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
                                })()}
                            </div>
                        </div>

                        {/* Input Area */}
                        {replyTo && (
                            <div className="px-3 md:px-4 py-2 bg-gray-50 dark:bg-gray-900 flex justify-between items-center text-xs text-gray-500 dark:text-gray-400">
                                <span>Replying to <span className="font-semibold">{replyTo.username}</span></span>
                                <button onClick={() => setReplyTo(null)} className="hover:text-gray-900 dark:hover:text-gray-200">
                                    <X size={14} />
                                </button>
                            </div>
                        )}
                        <form onSubmit={handlePostComment} className="border-t border-gray-100 dark:border-gray-800 p-3 md:p-4 flex items-center gap-3">
                            <button type="button" className="text-gray-900 dark:text-white hover:opacity-50">
                                <Smile size={24} />
                            </button>
                            <input
                                type="text"
                                placeholder={replyTo ? `Reply to ${replyTo.username}...` : "Add a comment..."}
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
