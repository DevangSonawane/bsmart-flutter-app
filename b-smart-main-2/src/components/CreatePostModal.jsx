import React, { useState, useRef, useCallback, useEffect } from 'react';
import { useSelector } from 'react-redux';
import { supabase } from '../lib/supabase';
import { Image, Video, X, ArrowLeft, Maximize2, Search, Copy, ZoomIn, Plus, ChevronLeft, ChevronRight, MapPin, UserPlus, ChevronDown, ChevronUp, Smile } from 'lucide-react';
import Cropper from 'react-easy-crop';

// Filter Definitions
const FILTERS = [
  { name: 'Original', style: '' },
  { name: 'Clarendon', style: 'contrast(1.2) saturate(1.25)' },
  { name: 'Gingham', style: 'brightness(1.05) hue-rotate(-10deg)' },
  { name: 'Moon', style: 'grayscale(1) contrast(1.1) brightness(1.1)' },
  { name: 'Lark', style: 'contrast(0.9)' },
  { name: 'Reyes', style: 'sepia(0.22) brightness(1.1) contrast(0.85) saturate(0.75)' },
  { name: 'Juno', style: 'contrast(1.2) brightness(1.1) saturate(1.4) sepia(0.2)' },
  { name: 'Slumber', style: 'brightness(1.05) saturate(0.66) sepia(0.20)' },
  { name: 'Crema', style: 'contrast(0.9) saturate(0.9) sepia(0.2)' },
  { name: 'Ludwig', style: 'contrast(0.9) saturate(0.9) brightness(1.1)' },
  { name: 'Aden', style: 'contrast(0.9) saturate(0.85) brightness(1.2) hue-rotate(-20deg)' },
  { name: 'Perpetua', style: 'contrast(1.1) brightness(1.1) saturate(1.1)' }
];

const ADJUSTMENTS = [
  { name: 'Brightness', property: 'brightness', min: -100, max: 100 },
  { name: 'Contrast', property: 'contrast', min: -100, max: 100 },
  { name: 'Saturation', property: 'saturate', min: -100, max: 100 },
  { name: 'Temperature', property: 'sepia', min: -100, max: 100 }, // Approximate
  { name: 'Fade', property: 'opacity', min: 0, max: 100 }, // Approximate
  { name: 'Vignette', property: 'vignette', min: 0, max: 100 } // Custom handling
];

// Utility to create image
const createImage = (url) =>
  new Promise((resolve, reject) => {
    const image = new window.Image()
    image.addEventListener('load', () => resolve(image))
    image.addEventListener('error', (error) => reject(error))
    image.setAttribute('crossOrigin', 'anonymous')
    image.src = url
  })

// Utility to crop image
async function getCroppedImg(imageSrc, pixelCrop) {
  const image = await createImage(imageSrc)
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')

  if (!pixelCrop) {
    const size = Math.min(image.width, image.height);
    pixelCrop = {
      x: (image.width - size) / 2,
      y: (image.height - size) / 2,
      width: size,
      height: size
    }
  }

  canvas.width = pixelCrop.width
  canvas.height = pixelCrop.height

  ctx.drawImage(
    image,
    pixelCrop.x,
    pixelCrop.y,
    pixelCrop.width,
    pixelCrop.height,
    0,
    0,
    pixelCrop.width,
    pixelCrop.height
  )

  return new Promise((resolve) => {
    canvas.toBlob((file) => {
      resolve(URL.createObjectURL(file))
    }, 'image/jpeg')
  })
}

const CreatePostModal = ({ isOpen, onClose }) => {
  const [isDragging, setIsDragging] = useState(false);
  const [step, setStep] = useState('select'); // 'select', 'crop', 'edit', 'share'
  const { userObject } = useSelector((state) => state.auth);

  // Media State
  const [media, setMedia] = useState([]);
  const [currentIndex, setCurrentIndex] = useState(0);

  // Share Step State
  const [caption, setCaption] = useState('');
  const [location, setLocation] = useState('');
  const [hideLikes, setHideLikes] = useState(false);
  const [turnOffCommenting, setTurnOffCommenting] = useState(false);
  const [isAdvancedSettingsOpen, setIsAdvancedSettingsOpen] = useState(false);

  // Tagging & Emoji State
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [tags, setTags] = useState([]); // { id, x, y, user: { id, username, avatar_url } }
  const [showTagSearch, setShowTagSearch] = useState(false);
  const [tagCoordinates, setTagCoordinates] = useState({ x: 0, y: 0 });
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [isSearchingUsers, setIsSearchingUsers] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const POPULAR_EMOJIS = ['😂', '😮', '😍', '😢', '👏', '🔥', '🎉', '💯', '❤️', '🤣', '🥰', '😘', '😭', '😊'];

  // UI State
  const [showRatioMenu, setShowRatioMenu] = useState(false);
  const [showZoomSlider, setShowZoomSlider] = useState(false);
  const [showMultiSelect, setShowMultiSelect] = useState(false);
  const [activeTab, setActiveTab] = useState('filters'); // 'filters', 'adjustments'

  const fileInputRef = useRef(null);

  const currentMedia = media[currentIndex];

  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);

    const files = Array.from(e.dataTransfer.files);
    if (files && files.length > 0) {
      handleFiles(files);
    }
  };

  const handleFileSelect = (e) => {
    const files = Array.from(e.target.files);
    if (files && files.length > 0) {
      handleFiles(files);
    }
    e.target.value = '';
  };

  const handleFiles = async (files) => {
    const newMedia = await Promise.all(files
      .filter(file => file.type.startsWith('image/') || file.type.startsWith('video/'))
      .map(async (file) => {
        const url = URL.createObjectURL(file);
        let aspect = 1;
        let originalAspect = null;

        if (file.type.startsWith('image/')) {
          try {
            const img = await createImage(url);
            originalAspect = img.width / img.height;
            aspect = originalAspect;
          } catch (e) {
            console.error("Error loading image dimensions", e);
          }
        }

        return {
          id: Math.random().toString(36).substr(2, 9),
          url,
          type: file.type.startsWith('image/') ? 'image' : 'video',
          crop: { x: 0, y: 0 },
          zoom: 1,
          aspect, // Initial aspect ratio matches image
          originalAspect,
          croppedAreaPixels: null,
          filter: 'Original',
          adjustments: {
            brightness: 0,
            contrast: 0,
            saturate: 0,
            sepia: 0,
            opacity: 0,
            vignette: 0
          }
        };
      }));

    if (step === 'select') {
      setMedia(newMedia);
      setCurrentIndex(0);
      setStep('crop');
    } else {
      setMedia(prev => [...prev, ...newMedia]);
      setCurrentIndex(prev => prev + newMedia.length - 1);
    }
  };

  const updateCurrentMedia = (updates) => {
    setMedia(prev => prev.map((item, index) =>
      index === currentIndex ? { ...item, ...updates } : item
    ));
  };

  const onCropChange = (crop) => {
    updateCurrentMedia({ crop });
  };

  const onZoomChange = (zoom) => {
    updateCurrentMedia({ zoom });
  };

  const onCropComplete = (croppedArea, croppedAreaPixels) => {
    updateCurrentMedia({ croppedAreaPixels });
  };

  const handleRemoveMedia = (index, e) => {
    e.stopPropagation();
    if (media.length === 1) {
      handleClose();
      return;
    }

    const newMedia = media.filter((_, i) => i !== index);
    setMedia(newMedia);
    if (currentIndex >= index && currentIndex > 0) {
      setCurrentIndex(prev => prev - 1);
    }
  };

  const handleButtonClick = () => {
    fileInputRef.current?.click();
  };

  const handleBack = () => {
    if (step === 'share') {
      setStep('edit');
    } else if (step === 'edit') {
      setStep('crop');
    } else if (step === 'crop') {
      setStep('select');
      setMedia([]);
      setCurrentIndex(0);
    } else {
      handleClose();
    }
  };

  const handleNextStep = async () => {
    if (step === 'crop') {
      // Generate cropped images
      const newMedia = await Promise.all(media.map(async (item) => {
        try {
          const croppedUrl = await getCroppedImg(item.url, item.croppedAreaPixels);
          return { ...item, croppedUrl };
        } catch (e) {
          console.error("Crop error", e);
          return { ...item, croppedUrl: item.url };
        }
      }));
      setMedia(newMedia);
      setStep('edit');
    } else if (step === 'edit') {
      setStep('share');
    } else if (step === 'share') {
      // Submit post
      if (isSubmitting) return;
      setIsSubmitting(true);

      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          alert("Please log in to share a post.");
          return;
        }

        // Upload images and prepare media array
        const processedMedia = await Promise.all(media.map(async (item) => {
          // Fetch blob from blob URL
          const response = await fetch(item.croppedUrl || item.url);
          const blob = await response.blob();

          const fileExt = blob.type.split('/')[1] || 'jpg';
          const fileName = `${user.id}/${Date.now()}_${Math.random().toString(36).substr(2, 9)}.${fileExt}`;

          const { error: uploadError } = await supabase.storage
            .from('post_images')
            .upload(fileName, blob);

          if (uploadError) throw uploadError;

          const { data: { publicUrl } } = supabase.storage
            .from('post_images')
            .getPublicUrl(fileName);

          return {
            image: publicUrl,
            ratio: item.aspect,
            zoom: item.zoom,
            filter: item.filter,
            adjustments: item.adjustments
          };
        }));

        // Insert post
        const { data: insertedPost, error: insertError } = await supabase
          .from('posts')
          .insert({
            user_id: user.id,
            caption,
            location,
            media: processedMedia,
            tags,
            hide_likes_count: hideLikes,
            turn_off_commenting: turnOffCommenting
          })
          .select()
          .single();

        if (insertError) throw insertError;

        // Append post ID to user's posts array
        const { error: updateError } = await supabase
          .rpc('append_post_id', {
            post_id: insertedPost.id,
            user_id_param: user.id
          });

        if (updateError) console.error("Error updating user post list:", updateError);

        handleClose();
        // clear state
        setMedia([]);
        setCaption('');
        setLocation('');
        setTags([]);
        // Optional: Trigger a feed refresh or show success toast
        alert("Post shared successfully!");

      } catch (error) {
        console.error("Error creating post:", error);
        alert("Failed to create post. Please try again.");
      } finally {
        setIsSubmitting(false);
      }
    }
  };

  // Tagging & Emoji Handlers
  const handleEmojiClick = (emoji) => {
    setCaption(prev => prev + emoji);
    setShowEmojiPicker(false);
  };

  const handleImageClick = (e) => {
    if (step !== 'share') return;

    // Don't trigger if clicking on an existing tag or close button
    if (e.target.closest('.tag-item')) return;

    const rect = e.currentTarget.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * 100;
    const y = ((e.clientY - rect.top) / rect.height) * 100;

    setTagCoordinates({ x, y });
    setShowTagSearch(true);
    setSearchQuery('');
    fetchUsers('');
  };

  const fetchUsers = async (query) => {
    setIsSearchingUsers(true);
    try {
      let queryBuilder = supabase
        .from('users')
        .select('id, username, avatar_url, full_name')
        .limit(20);

      if (query) {
        queryBuilder = queryBuilder.ilike('username', `%${query}%`);
      }

      const { data, error } = await queryBuilder;

      if (error) throw error;
      setSearchResults(data || []);
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setIsSearchingUsers(false);
    }
  };

  const handleTagUser = (user) => {
    const newTag = {
      id: Math.random().toString(36).substr(2, 9),
      x: tagCoordinates.x,
      y: tagCoordinates.y,
      user
    };
    setTags([...tags, newTag]);
    setShowTagSearch(false);
  };

  const handleRemoveTag = (e, tagId) => {
    e.stopPropagation();
    setTags(tags.filter(t => t.id !== tagId));
  };

  // Search Debounce
  useEffect(() => {
    if (showTagSearch) {
      const timer = setTimeout(() => {
        fetchUsers(searchQuery);
      }, 300);
      return () => clearTimeout(timer);
    }
  }, [searchQuery, showTagSearch]);

  const handleClose = () => {
    setStep('select');
    setMedia([]);
    setCurrentIndex(0);
    onClose();
  };

  const setAspect = (aspect) => {
    updateCurrentMedia({
      aspect,
      zoom: 1,
      crop: { x: 0, y: 0 }
    });
    setShowRatioMenu(false);
  };

  const applyFilter = (filterName) => {
    updateCurrentMedia({ filter: filterName });
  };

  const updateAdjustment = (property, value) => {
    const currentAdjustments = currentMedia.adjustments || {};
    updateCurrentMedia({
      adjustments: { ...currentAdjustments, [property]: value }
    });
  };

  const getFilterStyle = (item) => {
    if (!item) return {};
    const filterDef = FILTERS.find(f => f.name === item.filter);
    const baseFilter = filterDef ? filterDef.style : '';

    const adj = item.adjustments;
    // Convert adjustment values to CSS strings
    // Brightness: 0 -> 100%, 100 -> 200%, -100 -> 0%
    const brightness = `brightness(${100 + adj.brightness}%)`;
    const contrast = `contrast(${100 + adj.contrast}%)`;
    const saturate = `saturate(${100 + adj.saturate}%)`;
    // Sepia for temperature (warmth) - approx
    const sepia = adj.sepia !== 0 ? `sepia(${Math.abs(adj.sepia)}%)` : '';
    const hue = adj.sepia < 0 ? `hue-rotate(-${Math.abs(adj.sepia)}deg)` : (adj.sepia > 0 ? `hue-rotate(${adj.sepia}deg)` : '');

    return {
      filter: `${baseFilter} ${brightness} ${contrast} ${saturate} ${sepia} ${hue}`.trim(),
      opacity: (100 - adj.opacity) / 100
    };
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/65 p-4">
      <button
        onClick={handleClose}
        className="absolute top-4 right-4 text-white hover:text-gray-200"
      >
        <X size={24} />
      </button>

      <div className={`bg-white rounded-xl w-full ${step !== 'select' ? 'max-w-4xl h-[85vh] max-h-[850px]' : 'max-w-lg h-[70vh] max-h-[600px]'} overflow-hidden flex flex-col animate-in fade-in zoom-in duration-200 transition-all`}>
        {/* Header */}
        <div className="border-b border-gray-200 py-3 px-4 flex items-center justify-between relative z-10 bg-white">
          {step !== 'select' ? (
            <>
              <button onClick={handleBack} className="text-gray-900 hover:text-gray-600">
                <ArrowLeft size={24} />
              </button>
              <h2 className="font-semibold text-base absolute left-1/2 -translate-x-1/2">
                {step === 'crop' ? 'Crop' : step === 'edit' ? 'Edit' : 'Create new post'}
              </h2>
              <button
                onClick={handleNextStep}
                className={`text-[#0095f6] hover:text-[#00376b] font-semibold text-sm ${isSubmitting ? 'opacity-50 cursor-not-allowed' : ''}`}
                disabled={isSubmitting}
              >
                {step === 'share' ? (isSubmitting ? 'Sharing...' : 'Share') : 'Next'}
              </button>
            </>
          ) : (
            <h2 className="font-semibold text-base w-full text-center">Create new post</h2>
          )}
        </div>

        {/* Content */}
        {step === 'select' ? (
          <div
            className={`flex-1 flex flex-col items-center justify-center p-8 transition-colors ${isDragging ? 'bg-blue-50' : 'bg-white'}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
          >
            <div className="relative mb-4">
              <div className="relative">
                <Image size={64} className="text-gray-800 rotate-[-6deg] translate-x-[-10px]" strokeWidth={1} />
                <Video size={64} className="text-gray-800 absolute top-0 left-0 rotate-[6deg] translate-x-[10px] bg-white rounded-lg" strokeWidth={1} />
              </div>
            </div>
            <h3 className="text-xl font-light mb-6 text-gray-800">Drag photos and videos here</h3>
            <button
              onClick={handleButtonClick}
              className="bg-[#0095f6] hover:bg-[#1877f2] text-white px-4 py-1.5 rounded-md text-sm font-semibold transition-colors"
            >
              Select From Computer
            </button>
          </div>
        ) : step === 'crop' ? (
          <div className="flex-1 bg-[#f0f0f0] relative flex items-center justify-center overflow-hidden">
            {currentMedia && (
              <div className="relative w-full h-full">
                <Cropper
                  image={currentMedia.url}
                  crop={currentMedia.crop}
                  zoom={currentMedia.zoom}
                  aspect={currentMedia.aspect || 1}
                  onCropChange={onCropChange}
                  onCropComplete={onCropComplete}
                  onZoomChange={onZoomChange}
                  onMediaLoaded={(mediaSize) => {
                    const { naturalWidth, naturalHeight } = mediaSize;
                    if (naturalWidth && naturalHeight) {
                      const originalAspect = naturalWidth / naturalHeight;
                      if (!currentMedia.originalAspect || Math.abs(currentMedia.originalAspect - originalAspect) > 0.01) {
                        updateCurrentMedia({
                          originalAspect,
                          aspect: (!currentMedia.originalAspect && currentMedia.aspect === 1) ? originalAspect : currentMedia.aspect
                        });
                      }
                    }
                  }}
                  objectFit="contain"
                  showGrid={false}
                  style={{
                    containerStyle: { background: '#f0f0f0' },
                    cropAreaStyle: { border: '1px solid rgba(255, 255, 255, 0.5)' }
                  }}
                />
              </div>
            )}
            {/* ... Navigation Arrows & Controls (omitted for brevity, assume same as before but keeping concise here) ... */}
            {media.length > 1 && (
              <>
                {currentIndex > 0 && (
                  <button onClick={() => setCurrentIndex(prev => prev - 1)} className="absolute left-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronLeft size={20} /></button>
                )}
                {currentIndex < media.length - 1 && (
                  <button onClick={() => setCurrentIndex(prev => prev + 1)} className="absolute right-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronRight size={20} /></button>
                )}
              </>
            )}
            <div className="absolute bottom-4 left-4 flex gap-3 z-30">
              <div className="relative">
                {showRatioMenu && (
                  <div className="absolute bottom-full left-0 mb-2 bg-black/80 backdrop-blur-sm rounded-lg overflow-hidden flex flex-col w-32 shadow-xl">
                    <button onClick={() => setAspect(currentMedia.originalAspect || 1)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === currentMedia.originalAspect ? 'text-white' : 'text-gray-400'}`}><Image size={18} /> Original</button>
                    <button onClick={() => setAspect(1)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === 1 ? 'text-white' : 'text-gray-400'}`}><span className="w-5 h-5 border-2 border-current rounded-sm"></span> 1:1</button>
                    <button onClick={() => setAspect(4 / 5)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === 0.8 ? 'text-white' : 'text-gray-400'}`}><span className="w-4 h-5 border-2 border-current rounded-sm"></span> 4:5</button>
                    <button onClick={() => setAspect(16 / 9)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === 16 / 9 ? 'text-white' : 'text-gray-400'}`}><span className="w-5 h-3 border-2 border-current rounded-sm"></span> 16:9</button>
                  </div>
                )}
                <button onClick={() => { setShowRatioMenu(!showRatioMenu); setShowZoomSlider(false); setShowMultiSelect(false); }} className={`w-8 h-8 rounded-full ${showRatioMenu ? 'bg-white text-black' : 'bg-black/70 text-white'} hover:bg-white hover:text-black flex items-center justify-center transition-colors`}><Maximize2 size={16} /></button>
              </div>
              <div className="relative">
                {showZoomSlider && (
                  <div className="absolute bottom-full left-0 mb-2 p-3 bg-black/80 backdrop-blur-sm rounded-lg shadow-xl w-32">
                    <input type="range" min={1} max={3} step={0.1} value={currentMedia.zoom} onChange={(e) => onZoomChange(Number(e.target.value))} className="w-full h-1 bg-gray-600 rounded-lg appearance-none cursor-pointer accent-white" />
                  </div>
                )}
                <button onClick={() => { setShowZoomSlider(!showZoomSlider); setShowRatioMenu(false); setShowMultiSelect(false); }} className={`w-8 h-8 rounded-full ${showZoomSlider ? 'bg-white text-black' : 'bg-black/70 text-white'} hover:bg-white hover:text-black flex items-center justify-center transition-colors`}><ZoomIn size={16} /></button>
              </div>
            </div>
            <div className="absolute bottom-4 right-4 z-30">
              <div className="relative">
                {showMultiSelect && (
                  <div className="absolute bottom-full right-0 mb-2 p-3 bg-black/80 backdrop-blur-sm rounded-lg shadow-xl w-auto min-w-[200px] max-w-[300px]">
                    <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide">
                      {media.map((item, idx) => (
                        <div key={item.id} className={`relative flex-shrink-0 w-16 h-16 rounded overflow-hidden cursor-pointer border-2 ${idx === currentIndex ? 'border-white' : 'border-transparent'}`} onClick={() => setCurrentIndex(idx)}>
                          <img src={item.url} className="w-full h-full object-cover" alt="" />
                          <button onClick={(e) => handleRemoveMedia(idx, e)} className="absolute top-0.5 right-0.5 w-4 h-4 bg-black/50 rounded-full flex items-center justify-center text-white hover:bg-black/80"><X size={10} /></button>
                        </div>
                      ))}
                      <button onClick={handleButtonClick} className="flex-shrink-0 w-12 h-12 rounded-full border border-gray-500 flex items-center justify-center text-gray-400 hover:text-white hover:border-white transition-colors self-center ml-2"><Plus size={24} /></button>
                    </div>
                  </div>
                )}
                <button onClick={() => { setShowMultiSelect(!showMultiSelect); setShowRatioMenu(false); setShowZoomSlider(false); }} className={`w-8 h-8 rounded-full ${showMultiSelect ? 'bg-white text-black' : 'bg-black/70 text-white'} hover:bg-white hover:text-black flex items-center justify-center transition-colors`}><Copy size={16} /></button>
              </div>
            </div>
          </div>
        ) : step === 'edit' ? (
          /* EDIT STEP */
          <div className="flex-1 flex overflow-hidden">
            {/* Left: Image Preview */}
            <div className="flex-[2] bg-[#f0f0f0] flex items-center justify-center relative">
              {currentMedia && (
                <img
                  src={currentMedia.croppedUrl || currentMedia.url}
                  className="max-w-full max-h-full object-contain transition-all duration-200"
                  style={getFilterStyle(currentMedia)}
                  alt="Edit"
                />
              )}

              {/* Navigation Arrows for Edit Step */}
              {media.length > 1 && (
                <>
                  {currentIndex > 0 && (
                    <button onClick={() => setCurrentIndex(prev => prev - 1)} className="absolute left-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronLeft size={20} /></button>
                  )}
                  {currentIndex < media.length - 1 && (
                    <button onClick={() => setCurrentIndex(prev => prev + 1)} className="absolute right-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronRight size={20} /></button>
                  )}
                </>
              )}
            </div>

            {/* Right: Tools */}
            <div className="flex-1 bg-white border-l border-gray-200 flex flex-col min-w-[300px]">
              {/* User Profile Header (optional, usually here in instagram web) */}

              {/* Tabs */}
              <div className="flex border-b border-gray-200">
                <button
                  className={`flex-1 py-3 text-sm font-semibold transition-colors ${activeTab === 'filters' ? 'text-black border-b border-black' : 'text-gray-400 hover:text-gray-600'}`}
                  onClick={() => setActiveTab('filters')}
                >
                  Filters
                </button>
                <button
                  className={`flex-1 py-3 text-sm font-semibold transition-colors ${activeTab === 'adjustments' ? 'text-black border-b border-black' : 'text-gray-400 hover:text-gray-600'}`}
                  onClick={() => setActiveTab('adjustments')}
                >
                  Adjustments
                </button>
              </div>

              {/* Tab Content */}
              <div className="flex-1 overflow-y-auto p-4 scrollbar-hide">
                {activeTab === 'filters' ? (
                  <div className="grid grid-cols-3 gap-4">
                    {FILTERS.map((filter) => (
                      <div
                        key={filter.name}
                        className="cursor-pointer group text-center"
                        onClick={() => applyFilter(filter.name)}
                      >
                        <div className={`aspect-square rounded-md overflow-hidden mb-2 border-2 transition-all ${currentMedia.filter === filter.name ? 'border-[#0095f6]' : 'border-transparent group-hover:border-gray-300'}`}>
                          <img
                            src={currentMedia.croppedUrl || currentMedia.url}
                            className="w-full h-full object-cover"
                            style={{ filter: filter.style }}
                            alt={filter.name}
                          />
                        </div>
                        <span className={`text-xs ${currentMedia.filter === filter.name ? 'font-semibold text-[#0095f6]' : 'text-gray-500'}`}>
                          {filter.name}
                        </span>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="flex flex-col gap-6">
                    {ADJUSTMENTS.map((adj) => (
                      <div key={adj.name} className="flex flex-col gap-2">
                        <div className="flex justify-between items-center">
                          <span className="text-sm font-medium text-gray-700">{adj.name}</span>
                          <span className="text-xs text-gray-500">
                            {currentMedia.adjustments[adj.property] || 0}
                          </span>
                        </div>
                        <input
                          type="range"
                          min={adj.min}
                          max={adj.max}
                          value={currentMedia.adjustments[adj.property] || 0}
                          onChange={(e) => updateAdjustment(adj.property, parseInt(e.target.value))}
                          className="w-full h-1 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-black"
                        />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        ) : (
          /* SHARE STEP */
          <div className="flex-1 flex overflow-hidden">
            {/* Left: Final Image Preview */}
            <div className="flex-[2] bg-[#f0f0f0] flex items-center justify-center relative select-none">
              {currentMedia && (
                <div className="relative w-full h-full flex items-center justify-center" onClick={handleImageClick}>
                  <img
                    src={currentMedia.croppedUrl || currentMedia.url}
                    className="max-w-full max-h-full object-contain cursor-crosshair"
                    style={getFilterStyle(currentMedia)}
                    alt="Share Preview"
                  />
                  <div className="absolute bottom-4 left-1/2 -translate-x-1/2 bg-black/70 text-white text-xs px-3 py-1.5 rounded-full pointer-events-none">
                    Click photo to tag people
                  </div>

                  {/* Tags */}
                  {tags.map((tag) => (
                    <div
                      key={tag.id}
                      className="tag-item absolute bg-black/70 text-white px-3 py-1.5 rounded-lg flex items-center gap-2 transform -translate-x-1/2 -translate-y-1/2 cursor-default"
                      style={{ left: `${tag.x}%`, top: `${tag.y}%` }}
                    >
                      <div className="w-0 h-0 border-l-[6px] border-l-transparent border-r-[6px] border-r-transparent border-b-[6px] border-b-black/70 absolute -top-[6px] left-1/2 -translate-x-1/2"></div>
                      <span className="text-xs font-semibold">{tag.user.username}</span>
                      <button onClick={(e) => handleRemoveTag(e, tag.id)} className="hover:text-gray-300"><X size={12} /></button>
                    </div>
                  ))}

                  {/* Tag Search Popover */}
                  {showTagSearch && (
                    <div className="absolute z-50 bg-white rounded-lg shadow-xl w-64 overflow-hidden" style={{ left: '50%', top: '50%', transform: 'translate(-50%, -50%)' }}>
                      <div className="p-3 border-b border-gray-100 flex items-center justify-between">
                        <span className="font-semibold text-sm">Tag People</span>
                        <button onClick={(e) => { e.stopPropagation(); setShowTagSearch(false); }}><X size={18} /></button>
                      </div>
                      <div className="p-2">
                        <div className="relative">
                          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                          <input
                            type="text"
                            placeholder="Search user"
                            className="w-full bg-gray-100 rounded-md py-1.5 pl-9 pr-3 text-sm outline-none focus:ring-1 focus:ring-gray-300"
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            onClick={(e) => e.stopPropagation()}
                            autoFocus
                          />
                        </div>
                      </div>
                      <div className="max-h-48 overflow-y-auto">
                        {isSearchingUsers ? (
                          <div className="p-4 text-center text-gray-400 text-xs">Searching...</div>
                        ) : searchResults.length > 0 ? (
                          searchResults.map(user => (
                            <div
                              key={user.id}
                              className="flex items-center gap-3 p-3 hover:bg-gray-50 cursor-pointer"
                              onClick={(e) => { e.stopPropagation(); handleTagUser(user); }}
                            >
                              <div className="w-8 h-8 bg-gray-200 rounded-full overflow-hidden flex-shrink-0">
                                {user.avatar_url ? (
                                  <img src={user.avatar_url} className="w-full h-full object-cover" alt={user.username} />
                                ) : (
                                  <div className="w-full h-full bg-gradient-to-tr from-yellow-400 to-purple-600"></div>
                                )}
                              </div>
                              <div className="flex flex-col overflow-hidden">
                                <span className="text-sm font-semibold truncate">{user.username}</span>
                                <span className="text-xs text-gray-500 truncate">{user.full_name}</span>
                              </div>
                            </div>
                          ))
                        ) : (
                          <div className="p-4 text-center text-gray-400 text-xs">No users found</div>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              )}
              {/* Navigation Arrows for Share Step (Carousel) */}
              {media.length > 1 && (
                <>
                  {currentIndex > 0 && (
                    <button onClick={() => setCurrentIndex(prev => prev - 1)} className="absolute left-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronLeft size={20} /></button>
                  )}
                  {currentIndex < media.length - 1 && (
                    <button onClick={() => setCurrentIndex(prev => prev + 1)} className="absolute right-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 hover:bg-white text-gray-800 shadow-md flex items-center justify-center"><ChevronRight size={20} /></button>
                  )}
                </>
              )}
            </div>

            {/* Right: Share Details */}
            <div className="flex-1 bg-white border-l border-gray-200 flex flex-col min-w-[340px] overflow-y-auto">
              {/* User Info */}
              <div className="flex items-center gap-3 p-4">
                <div className="w-8 h-8 bg-gray-200 rounded-full overflow-hidden">
                  {userObject?.avatar_url ? (
                    <img src={userObject.avatar_url} className="w-full h-full object-cover" alt={userObject.username} />
                  ) : (
                    <div className="w-full h-full bg-gradient-to-tr from-yellow-400 to-purple-600"></div>
                  )}
                </div>
                <span className="font-semibold text-sm">{userObject?.username || 'User'}</span>
              </div>

              {/* Caption */}
              <div className="px-4 pb-4 border-b border-gray-100 relative">
                <textarea
                  className="w-full min-h-[150px] resize-none outline-none text-sm placeholder-gray-400"
                  placeholder="Write a caption..."
                  value={caption}
                  onChange={(e) => setCaption(e.target.value)}
                  maxLength={2200}
                />
                <div className="flex items-center justify-between mt-2">
                  <div className="relative">
                    <button onClick={() => setShowEmojiPicker(!showEmojiPicker)} className="text-gray-400 hover:text-gray-600"><Smile size={20} /></button>
                    {showEmojiPicker && (
                      <div className="absolute bottom-full left-0 mb-2 bg-white rounded-lg shadow-xl border border-gray-100 p-2 w-64 z-50">
                        <div className="text-xs font-semibold text-gray-500 mb-2 px-1">Most popular</div>
                        <div className="grid grid-cols-7 gap-1">
                          {POPULAR_EMOJIS.map(emoji => (
                            <button
                              key={emoji}
                              onClick={() => handleEmojiClick(emoji)}
                              className="w-8 h-8 flex items-center justify-center text-xl hover:bg-gray-100 rounded"
                            >
                              {emoji}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                  <span className="text-xs text-gray-400">{caption.length}/2,200</span>
                </div>
              </div>

              {/* Settings Rows */}
              <div className="flex flex-col">
                <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 cursor-pointer hover:bg-gray-50">
                  <span className="text-sm text-gray-700">Add Tag</span>
                  <UserPlus size={20} className="text-gray-800" />
                </div>

                {/* Advanced Settings Accordion */}
                <div className="border-b border-gray-100">
                  <div
                    className="flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-gray-50"
                    onClick={() => setIsAdvancedSettingsOpen(!isAdvancedSettingsOpen)}
                  >
                    <span className="text-sm text-gray-800 font-medium">Advanced Settings</span>
                    {isAdvancedSettingsOpen ? <ChevronUp size={20} className="text-gray-600" /> : <ChevronDown size={20} className="text-gray-600" />}
                  </div>
                  {isAdvancedSettingsOpen && (
                    <div className="px-4 pb-4 flex flex-col gap-4">
                      <div className="flex flex-col gap-2">
                        <div className="flex items-center justify-between">
                          <span className="text-sm text-gray-800">Hide like and view counts on this post</span>
                          <div className="relative inline-flex items-center cursor-pointer" onClick={() => setHideLikes(!hideLikes)}>
                            <input type="checkbox" className="sr-only peer" checked={hideLikes} readOnly />
                            <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                          </div>
                        </div>
                        <p className="text-xs text-gray-500">
                          Only you will see the total number of likes and views on this post. You can change this later by going to the ... menu at the top of the post. To hide like counts on other people's posts, go to your account settings. <span className="text-blue-500 cursor-pointer">Learn more</span>
                        </p>
                      </div>

                      <div className="flex flex-col gap-2">
                        <div className="flex items-center justify-between">
                          <span className="text-sm text-gray-800">Turn off commenting</span>
                          <div className="relative inline-flex items-center cursor-pointer" onClick={() => setTurnOffCommenting(!turnOffCommenting)}>
                            <input type="checkbox" className="sr-only peer" checked={turnOffCommenting} readOnly />
                            <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                          </div>
                        </div>
                        <p className="text-xs text-gray-500">
                          You can change this later by going to the ... menu at the top of your post.
                        </p>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      <input
        type="file"
        ref={fileInputRef}
        className="hidden"
        multiple
        accept="image/*,video/*"
        onChange={handleFileSelect}
      />
    </div>
  );
};

export default CreatePostModal;
