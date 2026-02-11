import React, { useState, useRef, useCallback, useEffect } from 'react';
import { useSelector } from 'react-redux';
import api from '../lib/api';
import { Image, Images, Video, X, ArrowLeft, Maximize2, Search, Copy, ZoomIn, Plus, ChevronLeft, ChevronRight, MapPin, UserPlus, ChevronDown, ChevronUp, Smile, Sun, Moon, Droplet, Thermometer, Cloud, Circle, Sliders } from 'lucide-react';
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

const CreatePostModal = ({ isOpen, onClose, initialType = 'post' }) => {
  const [isDragging, setIsDragging] = useState(false);
  const [step, setStep] = useState('select'); // 'select', 'crop', 'edit', 'share'
  const { userObject } = useSelector((state) => state.auth);
  const [postType, setPostType] = useState(initialType);

  useEffect(() => {
    if (isOpen) {
      setPostType(initialType);
    }
  }, [isOpen, initialType]);

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
  const [activeAdjustment, setActiveAdjustment] = useState(null);

  const ADJUSTMENT_ICONS = {
    'Brightness': Sun,
    'Contrast': Moon,
    'Saturation': Droplet,
    'Temperature': Thermometer,
    'Fade': Cloud,
    'Vignette': Circle
  };

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
    // Process files immediately
    const validFiles = files.filter(file => file.type.startsWith('image/') || file.type.startsWith('video/'));

    if (validFiles.length === 0) return;

    const newMedia = await Promise.all(validFiles.map(async (file) => {
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
        aspect,
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
      // Force step transition
      setTimeout(() => setStep('crop'), 0);
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
        if (!userObject) {
          alert("Please log in to share a post.");
          return;
        }

        // Upload images and prepare media array
        const processedMedia = await Promise.all(media.map(async (item) => {
          // Fetch blob from blob URL or generate filtered blob
          let blob;
          try {
            blob = await applyFiltersToImage(item);
          } catch (e) {
            console.error("Error applying filters, falling back to original", e);
            const response = await fetch(item.croppedUrl || item.url);
            blob = await response.blob();
          }

          const fileExt = blob.type.split('/')[1] || 'jpg';
          const fileName = `upload_${Date.now()}_${Math.random().toString(36).substr(2, 9)}.${fileExt}`;
          const file = new File([blob], fileName, { type: blob.type });

          const formData = new FormData();
          formData.append('file', file);

          const uploadResponse = await api.post('/upload', formData, {
            headers: {
              'Content-Type': 'multipart/form-data',
            },
          });

          const { fileUrl, fileName: serverFileName } = uploadResponse.data;

          // Generate Filter CSS
          const filterDef = FILTERS.find(f => f.name === item.filter);
          const baseFilter = filterDef ? filterDef.style : '';
          const adj = item.adjustments;
          const brightness = `brightness(${100 + adj.brightness}%)`;
          const contrast = `contrast(${100 + adj.contrast}%)`;
          const saturate = `saturate(${100 + adj.saturate}%)`;
          const sepia = adj.sepia !== 0 ? `sepia(${Math.abs(adj.sepia)}%)` : '';
          const hue = adj.sepia < 0 ? `hue-rotate(-${Math.abs(adj.sepia)}deg)` : (adj.sepia > 0 ? `hue-rotate(${adj.sepia}deg)` : '');

          const filterCss = `${baseFilter} ${brightness} ${contrast} ${saturate} ${sepia} ${hue}`.trim();

          return {
            fileName: serverFileName || fileName,
            type: item.type === 'video' ? 'video' : 'image',
            fileUrl: fileUrl,
            crop: {
              mode: "original",
              zoom: item.zoom,
              x: item.crop.x,
              y: item.crop.y
            },
            filter: {
              name: item.filter,
              css: filterCss
            },
            adjustments: {
              brightness: item.adjustments.brightness,
              contrast: item.adjustments.contrast,
              saturation: item.adjustments.saturate,
              temperature: item.adjustments.sepia,
              fade: item.adjustments.opacity,
              vignette: item.adjustments.vignette
            }
          };
        }));

        // Extract hashtags from caption
        const hashtags = caption.match(/#[a-zA-Z0-9_]+/g) || [];

        const payload = {
          caption,
          location,
          media: processedMedia,
          tags: hashtags,
          people_tags: tags.map(t => ({
            user_id: t.user.id,
            username: t.user.username,
            x: t.x,
            y: t.y
          })),
          hide_likes_count: hideLikes,
          turn_off_commenting: turnOffCommenting,
          type: postType
        };

        await api.post('/posts', payload);

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
      const { data } = await api.get(`/users/search?q=${query}`);
      setSearchResults(data || []);
    } catch (error) {
      console.error('Error fetching users:', error);
      setSearchResults([]);
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

  const applyFiltersToImage = async (item) => {
    const imageUrl = item.croppedUrl || item.url;
    if (item.type === 'video') return await (await fetch(imageUrl)).blob();

    return new Promise((resolve, reject) => {
      const img = new window.Image();
      img.crossOrigin = "anonymous";
      img.onload = () => {
        const canvas = document.createElement('canvas');
        canvas.width = img.width;
        canvas.height = img.height;
        const ctx = canvas.getContext('2d');

        // Apply filters
        const filterStyle = getFilterStyle(item);
        if (filterStyle.filter) {
          ctx.filter = filterStyle.filter;
        }
        if (filterStyle.opacity !== undefined && filterStyle.opacity !== 1) {
          ctx.globalAlpha = filterStyle.opacity;
        }

        ctx.drawImage(img, 0, 0, img.width, img.height);

        canvas.toBlob((blob) => {
          if (blob) {
            resolve(blob);
          } else {
            reject(new Error('Canvas to Blob conversion failed'));
          }
        }, 'image/jpeg', 0.95);
      };
      img.onerror = (e) => reject(e);
      img.src = imageUrl;
    });
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[60] bg-black/60 backdrop-blur-sm flex items-center justify-center p-0 md:p-8">
      {/* Close Button (Top Right) */}
      <button onClick={handleClose} className="absolute top-4 right-4 text-white z-50 md:block hidden">
        <X size={32} />
      </button>

      {/* Main Container */}
      <div className={`bg-white dark:bg-[#262626] md:max-h-[85vh] md:rounded-xl overflow-hidden flex flex-col transition-all duration-300 shadow-2xl ${step === 'select'
        ? 'w-full h-full md:w-[500px] md:h-[550px]'
        : step === 'crop'
          ? 'w-full h-full md:w-[750px] md:h-[800px]'
          : 'w-full h-full md:w-[1100px] md:h-[800px]'
        }`}>

        {/* Header */}
        <div className="h-[45px] border-b border-gray-200 dark:border-gray-800 flex items-center justify-between px-4 bg-white dark:bg-[#262626] sticky top-0 z-40">
          {step === 'select' ? (
            <>
              <div className="w-10"></div> {/* Spacer */}
              <h2 className="font-semibold text-base text-center dark:text-white flex-1">Create new {postType === 'reel' ? 'reel' : 'post'}</h2>
              <button onClick={handleClose} className="text-black dark:text-white md:hidden">
                <X size={24} />
              </button>
              <div className="w-10 md:block hidden"></div> {/* Spacer */}
            </>
          ) : (
            <>
              <div className="w-20 flex justify-start">
                <button onClick={handleBack} className="text-black dark:text-white p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors">
                  <ArrowLeft size={24} />
                </button>
              </div>
              <h2 className="font-semibold text-base text-center dark:text-white flex-1">{step === 'crop' ? 'Crop' : step === 'edit' ? 'Edit' : 'Create new post'}</h2>
              <div className="w-20 flex justify-end">
                <button onClick={handleNextStep} className="text-[#0095f6] hover:text-[#00376b] dark:hover:text-blue-400 font-semibold text-sm transition-colors">
                  {step === 'share' ? 'Share' : 'Next'}
                </button>
              </div>
            </>
          )}
        </div>

        {/* Content */}
        {step === 'select' ? (
          <div
            className={`flex-1 flex flex-col items-center justify-center p-8 transition-colors ${isDragging ? 'bg-blue-50 dark:bg-blue-900/20' : 'bg-white dark:bg-[#262626]'}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
          >
            <div className="relative mb-6">
              <div className="absolute inset-0 blur-xl rounded-full bg-gradient-to-tr from-purple-500/20 to-blue-500/20"></div>
              <div className="relative flex items-center justify-center w-24 h-24 rounded-xl bg-gray-100 dark:bg-gray-800">
                <Images size={56} className="text-gray-800 dark:text-white" />
              </div>
              <svg aria-label="Icon to represent media such as images or videos" className="hidden" color="currentColor" fill="currentColor" height="77" role="img" viewBox="0 0 97.6 77.3" width="96">
                <path d="M16.3 24h.3c2.8-.2 4.9-2.6 4.8-5.4-.2-2.8-2.6-4.9-5.4-4.8s-4.9 2.6-4.8 5.4c.1 2.7 2.4 4.8 5.1 4.8zm-2.4-7.2c.5-.6 1.3-1 2.1-1h.2c1.7 0 3.1 1.4 3.1 3.1 0 1.7-1.4 3.1-3.1 3.1-1.7 0-3.1-1.4-3.1-3.1 0-.8.3-1.5.8-2.1z" fill="currentColor"></path>
                <path d="M84.7 18.4 58 16.9l-.2-3c-.3-5.7-5.2-10.1-11-9.8L12.9 6c-5.7.3-10.1 5.3-9.8 11L5 51v.8c.7 5.2 5.1 9.1 10.3 9.1h.6l21.7-1.2v.6c-.3 5.7 4 10.7 9.8 11l34 2h.6c5.5 0 10.1-4.3 10.4-9.8l2-34c.4-5.8-4-10.7-9.7-11.1zM7.2 10.8C8.7 9.1 10.8 8.1 13 8l34-1.9c4.6-.3 8.6 3.3 8.9 7.9l.2 2.8-5.3-.3c-5.7-.3-10.7 4-11 9.8l-.6 9.5-9.5 10.7c-.2.3-.6.4-1 .5-.4 0-.7-.1-1-.4l-7.8-7c-1.4-1.3-3.5-1.1-4.9.3L7 45.5c-1.7-3.5-1.5-7.5.9-10.8l1.4-1.8c.5-.7.4-1.6-.2-2.2-.7-.5-1.6-.4-2.2.2L6 32.1c-2.6-3.3-3.6-7.6-2.5-11.7.9-3.7 3.2-7 6.6-8.9l-.9-1.3c-.6-.7-.5-1.6.2-2.2.6-.5 1.5-.5 2.1.2l1.6 1.8c.8.8 1.9 1.2 3.1 1.2.4 0 .9-.1 1.3-.2.9-.2 1.5-1 1.5-1.9 0-1.1-.9-2-2-1.9zm-2.1 7.2c.4-.4.7-1 1-1.6.1-.2.2-.4.4-.5.3-.2.6-.3.9-.2.2.1.3.2.3.4 0 .2-.1.3-.2.4-.1.1-.2.2-.3.3-.3.4-.6.9-.9 1.3-.1.1-.1.2-.1.3 0 .1.1.2.2.2.1 0 .2 0 .3-.1 1.1-.7 2.3-1.2 3.6-1.4 2.8-.4 5.6.5 7.6 2.4s2.9 4.7 2.5 7.5c-.2 1.3-.8 2.5-1.5 3.5-.1.1-.2.2-.2.3 0 .1.1.2.2.2.1 0 .2 0 .3-.1 1.3-.8 2.7-1.3 4.2-1.5 1.5-.2 3.1-.1 4.5.4 1.5.5 2.8 1.4 3.8 2.6s1.6 2.6 1.9 4.1c.1.7.1 1.4 0 2.1-.1.4-.2.8-.3 1.2-.1.3-.1.5.1.7.2.2.5.2.7.1.5-.3.9-.7 1.3-1.1.8-.9 1.5-2 1.9-3.1.2-.4.4-.8.5-1.3 0-.1.1-.2.2-.3.1 0 .2 0 .3.1.5.4 1 .9 1.3 1.4.3.5.6 1.1.7 1.6.1.4.3.7.6.9.3.2.7.2 1-.1.4-.5.8-1 1.1-1.6.3-.5.5-1.1.7-1.7.1-.5.6-.9 1.1-.8.5.1.9.6.8 1.1-.2.8-.4 1.5-.8 2.2-.3.7-.8 1.4-1.3 2-.2.2-.3.5-.3.8 0 .3.2.5.5.6.8.2 1.5.6 2.2 1.1.7.5 1.3 1.1 1.8 1.8.2.3.5.5.9.5.1 0 .2 0 .3-.1.4-.2.6-.7.5-1.1-.3-.9-.7-1.7-1.3-2.5-.5-.8-1.2-1.5-1.9-2.1-.3-.2-.5-.6-.5-.9 0-.3.2-.6.5-.7.8-.3 1.6-.5 2.4-.6.8-.1 1.6-.1 2.4.1.4.1.7-.1.9-.5.1-.4-.1-.8-.5-.9-.9-.3-1.9-.4-2.8-.3-1 .1-1.9.3-2.8.7-.3.1-.6.1-.8-.2-.3-.3-.4-.7-.2-1 .5-.9 1.1-1.7 1.9-2.4.7-.6 1.6-1.1 2.5-1.4.4-.1.6-.5.5-.9-.1-.4-.5-.6-.9-.5-1.1.3-2.1.8-2.9 1.5-.9.7-1.6 1.6-2.1 2.6-.2.3-.5.4-.8.4-.1 0-.2 0-.3-.1-.4-.2-.6-.6-.5-1 .3-1.1.8-2.1 1.5-2.9.7-.9 1.6-1.6 2.6-2.1.4-.2.5-.6.3-1-.2-.4-.6-.5-1-.3-1.1.5-2.1 1.3-2.9 2.3-.8.9-1.4 2-1.8 3.2-.1.4-.5.6-.9.5-.4-.1-.6-.5-.5-.9.4-1.2 1-2.3 1.9-3.2.8-1 1.9-1.7 3-2.2.4-.2.6-.6.4-1-.2-.4-.6-.6-1-.4-1.3.5-2.4 1.3-3.4 2.4-.9 1.1-1.6 2.3-2 3.6-.1.4-.5.6-.9.5-.4-.1-.6-.5-.5-.9.5-1.3 1.2-2.5 2.2-3.6 1-1 2.2-1.8 3.5-2.3.4-.2.6-.6.4-1-.2-.4-.6-.6-1-.4-1.5.6-2.8 1.4-3.9 2.6-1.1 1.1-1.9 2.5-2.5 3.9-.2.4-.6.6-1 .4-.4-.2-.6-.6-.4-1 .7-1.6 1.6-3.1 2.9-4.3 1.2-1.2 2.7-2.1 4.3-2.7.4-.2.6-.6.4-1-.2-.4-.6-.6-1-.4-1.8.6-3.4 1.6-4.8 2.9-1.4 1.4-2.4 3-3 4.8-.1.4-.5.6-.9.5-.4-.1-.6-.5-.5-.9.7-2 1.9-3.7 3.4-5.2 1.6-1.4 3.4-2.5 5.5-3.2.4-.1.7.1.8.5.1.4-.1.7-.5.8-1.8.6-3.4 1.6-4.8 2.8-1.4 1.3-2.4 2.9-3 4.6-.1.4-.5.6-.9.5-.4-.1-.6-.5-.5-.9.7-1.9 1.8-3.6 3.2-5 .2-.2.4-.4.6-.6.3-.2.7-.2.9.1.2.3.2.7-.1.9zm-8.8 32.6-3.7 3.3c-.1.1-.2.2-.4.2-.2 0-.3-.1-.4-.2l-5.6-6.3c-.6-.7-1.7-.7-2.3 0L37.7 54h35.7l-15.1-17.8c-.7-.8-1.9-.8-2.6 0z" fill="currentColor"></path>
              </svg>
            </div>
            <h3 className="text-xl font-normal mb-6 text-gray-800 dark:text-gray-200">Drag photos and videos here</h3>
            <button
              onClick={handleButtonClick}
              className="bg-[#0095f6] hover:bg-[#1877f2] text-white px-4 py-2 rounded-lg text-sm font-semibold transition-colors"
            >
              Select From Computer
            </button>
          </div>
        ) : step === 'crop' ? (
          <div className="flex-1 bg-[#f0f0f0] dark:bg-[#121212] relative flex items-center justify-center overflow-hidden">
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
                    containerStyle: { background: 'transparent' },
                    cropAreaStyle: { border: '1px solid rgba(255, 255, 255, 0.5)' }
                  }}
                />
              </div>
            )}
            {/* ... Navigation Arrows & Controls (omitted for brevity, assume same as before but keeping concise here) ... */}
            {media.length > 1 && (
              <>
                {currentIndex > 0 && (
                  <button onClick={() => setCurrentIndex(prev => prev - 1)} className="absolute left-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 dark:bg-black/80 hover:bg-white dark:hover:bg-black text-gray-800 dark:text-white shadow-md flex items-center justify-center"><ChevronLeft size={20} /></button>
                )}
                {currentIndex < media.length - 1 && (
                  <button onClick={() => setCurrentIndex(prev => prev + 1)} className="absolute right-4 top-1/2 -translate-y-1/2 z-20 w-8 h-8 rounded-full bg-white/90 dark:bg-black/80 hover:bg-white dark:hover:bg-black text-gray-800 dark:text-white shadow-md flex items-center justify-center"><ChevronRight size={20} /></button>
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
            </div>
            <div className="absolute bottom-4 right-4 flex gap-3 z-30">
              <div className="relative">
                {showZoomSlider && (
                  <div className="absolute bottom-full right-0 mb-2 p-3 bg-black/80 backdrop-blur-sm rounded-lg shadow-xl w-32">
                    <input type="range" min={1} max={3} step={0.1} value={currentMedia.zoom} onChange={(e) => onZoomChange(Number(e.target.value))} className="w-full h-1 bg-gray-600 rounded-lg appearance-none cursor-pointer accent-white" />
                  </div>
                )}
                <button onClick={() => { setShowZoomSlider(!showZoomSlider); setShowRatioMenu(false); setShowMultiSelect(false); }} className={`w-8 h-8 rounded-full ${showZoomSlider ? 'bg-white text-black' : 'bg-black/70 text-white'} hover:bg-white hover:text-black flex items-center justify-center transition-colors`}><ZoomIn size={16} /></button>
              </div>
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
          <div className="flex-1 flex lg:flex-row flex-col lg:overflow-hidden overflow-y-auto">
            {/* Left: Image Preview */}
            <div className="relative bg-[#f0f0f0] dark:bg-[#121212] flex items-center justify-center w-full flex-1 h-auto">
              {currentMedia && (
                currentMedia.type === 'video' ? (
                  <video
                    src={currentMedia.croppedUrl || currentMedia.url}
                    className="max-w-full max-h-full object-contain transition-all duration-200"
                    style={getFilterStyle(currentMedia)}
                    controls
                    autoPlay
                    loop
                    muted
                  />
                ) : (
                  <img
                    src={currentMedia.croppedUrl || currentMedia.url}
                    className="lg:max-w-full lg:max-h-full object-contain w-[400px] h-[500px]  transition-all duration-200"
                    style={getFilterStyle(currentMedia)}
                    alt="Edit"
                  />
                )
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
            <div className="bg-white dark:bg-black border-l border-gray-200 dark:border-gray-800 flex flex-col lg:w-[340px] w-full min-w-[340px] flex-none">
              {/* Tabs */}
              <div className="flex border-b border-gray-200 dark:border-gray-800">
                <button
                  className={`flex-1 py-3 text-sm font-semibold transition-colors ${activeTab === 'filters' ? 'text-black dark:text-white border-b border-black dark:border-white' : 'text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'}`}
                  onClick={() => setActiveTab('filters')}
                >
                  Filter
                </button>
                <button
                  className={`flex-1 py-3 text-sm font-semibold transition-colors ${activeTab === 'adjustments' ? 'text-black dark:text-white border-b border-black dark:border-white' : 'text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'}`}
                  onClick={() => setActiveTab('adjustments')}
                >
                  Adjustment
                </button>
              </div>

              {/* Tab Content */}
              <div className="flex flex-col h-full overflow-y-scroll scrollbar-hide px-5 py-5">
                {activeTab === 'filters' ? (
                  <div className="grid grid-cols-3 gap-4 ">
                    {FILTERS.map((filter) => (
                      <div
                        key={filter.name}
                        className="flex flex-col items-center gap-2 cursor-pointer group"
                        onClick={() => applyFilter(filter.name)}
                      >
                        <div className={`w-full aspect-square rounded-md overflow-hidden border-2 transition-all ${currentMedia.filter === filter.name ? 'border-[#0095f6]' : 'border-transparent'}`}>
                          {currentMedia.type === 'video' ? (
                            <video
                              src={currentMedia.croppedUrl || currentMedia.url}
                              className="w-full h-full object-cover"
                              style={{ filter: filter.style }}
                              muted
                            />
                          ) : (
                            <img
                              src={currentMedia.croppedUrl || currentMedia.url}
                              className="w-full h-full object-cover"
                              style={{ filter: filter.style }}
                              alt={filter.name}
                            />
                          )}
                        </div>
                        <span className={`text-xs font-semibold ${currentMedia.filter === filter.name ? 'text-[#0095f6]' : 'text-gray-500 dark:text-gray-400'}`}>
                          {filter.name}
                        </span>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="flex flex-col gap-6 pb-4">
                    {ADJUSTMENTS.map((adj) => (
                      <div key={adj.name} className="flex flex-col gap-3">
                        <div className="flex justify-between items-center">
                          <span className="text-sm font-semibold dark:text-white">{adj.name}</span>
                          {currentMedia.adjustments[adj.property] !== 0 && (
                            <button
                              onClick={() => updateAdjustment(adj.property, 0)}
                              className="text-xs text-blue-500 font-semibold hover:text-blue-600"
                            >
                              Reset
                            </button>
                          )}
                        </div>
                        <div className="flex items-center gap-3">
                          <input
                            type="range"
                            min={adj.min}
                            max={adj.max}
                            value={currentMedia.adjustments[adj.property] || 0}
                            onChange={(e) => updateAdjustment(adj.property, parseInt(e.target.value))}
                            className="flex-1 h-1 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-black dark:accent-white"
                          />
                          <span className="text-xs font-mono w-8 text-right text-gray-500 dark:text-gray-400">
                            {currentMedia.adjustments[adj.property] || 0}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        ) : (
          /* SHARE STEP */
          <div className="flex-1 flex flex-col md:flex-row lg:overflow-hidden overflow-y-auto">
            {/* Left: Final Image Preview */}
            <div className="relative bg-[#f0f0f0] dark:bg-[#121212] flex items-center justify-center select-none w-full h-[40%] md:h-auto md:flex-[2]">
              {currentMedia && (
                <div className="relative w-full h-full flex items-center justify-center" onClick={handleImageClick}>
                  {currentMedia.type === 'video' ? (
                    <video
                      src={currentMedia.croppedUrl || currentMedia.url}
                      className="max-w-full max-h-full object-contain"
                      style={getFilterStyle(currentMedia)}
                      controls
                      autoPlay
                      loop
                      muted
                    />
                  ) : (
                    <img
                      src={currentMedia.croppedUrl || currentMedia.url}
                      className="max-w-full max-h-full object-contain cursor-crosshair"
                      style={getFilterStyle(currentMedia)}
                      alt="Share Preview"
                    />
                  )}
                  {currentMedia.type !== 'video' && (
                    <div className="absolute bottom-4 left-1/2 -translate-x-1/2 bg-black/70 text-white text-xs px-3 py-1.5 rounded-full pointer-events-none">
                      Click photo to tag people
                    </div>
                  )}

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
                    <div className="absolute z-50 bg-white dark:bg-gray-800 rounded-lg shadow-xl w-64 overflow-hidden" style={{ left: '50%', top: '50%', transform: 'translate(-50%, -50%)' }}>
                      <div className="p-3 border-b border-gray-100 dark:border-gray-700 flex items-center justify-between">
                        <span className="font-semibold text-sm dark:text-white">Tag People</span>
                        <button onClick={(e) => { e.stopPropagation(); setShowTagSearch(false); }} className="dark:text-white"><X size={18} /></button>
                      </div>
                      <div className="p-2">
                        <div className="relative">
                          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                          <input
                            type="text"
                            placeholder="Search user"
                            className="w-full bg-gray-100 dark:bg-gray-700 rounded-md py-1.5 pl-9 pr-3 text-sm outline-none focus:ring-1 focus:ring-gray-300 dark:text-white dark:placeholder-gray-400"
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
                              className="flex items-center gap-3 p-3 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer"
                              onClick={(e) => { e.stopPropagation(); handleTagUser(user); }}
                            >
                              <div className="w-8 h-8 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden flex-shrink-0">
                                {user.avatar_url ? (
                                  <img src={user.avatar_url} className="w-full h-full object-cover" alt={user.username} />
                                ) : (
                                  <div className="w-full h-full bg-gradient-to-tr from-yellow-400 to-purple-600"></div>
                                )}
                              </div>
                              <div className="flex flex-col overflow-hidden">
                                <span className="text-sm font-semibold truncate dark:text-white">{user.username}</span>
                                <span className="text-xs text-gray-500 dark:text-gray-400 truncate">{user.full_name}</span>
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
            <div className="flex-1 bg-white dark:bg-black border-t md:border-t-0 md:border-l border-gray-200 dark:border-gray-800 flex flex-col w-full md:w-auto md:min-w-[340px] overflow-y-auto">
              {/* User Info */}
              <div className="flex items-center gap-3 p-4">
                <div className="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
                  {userObject?.avatar_url ? (
                    <img src={userObject.avatar_url} className="w-full h-full object-cover" alt={userObject.username} />
                  ) : (
                    <div className="w-full h-full bg-gradient-to-tr from-yellow-400 to-purple-600"></div>
                  )}
                </div>
                <span className="font-semibold text-sm dark:text-white">{userObject?.username || 'User'}</span>
              </div>

              {/* Caption */}
              <div className="px-4 pb-4 border-b border-gray-100 dark:border-gray-800 relative">
                <textarea
                  className="w-full min-h-[150px] resize-none outline-none text-sm placeholder-gray-400 bg-transparent dark:text-white"
                  placeholder="Write a caption..."
                  value={caption}
                  onChange={(e) => setCaption(e.target.value)}
                  maxLength={2200}
                />
                <div className="flex items-center justify-between mt-2">
                  <div className="relative">
                    <button onClick={() => setShowEmojiPicker(!showEmojiPicker)} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"><Smile size={20} /></button>
                    {showEmojiPicker && (
                      <div className="absolute bottom-full left-0 mb-2 bg-white dark:bg-gray-800 rounded-lg shadow-xl border border-gray-100 dark:border-gray-700 p-2 w-64 z-50">
                        <div className="text-xs font-semibold text-gray-500 dark:text-gray-400 mb-2 px-1">Most popular</div>
                        <div className="grid grid-cols-7 gap-1">
                          {POPULAR_EMOJIS.map(emoji => (
                            <button
                              key={emoji}
                              onClick={() => handleEmojiClick(emoji)}
                              className="w-8 h-8 flex items-center justify-center text-xl hover:bg-gray-100 dark:hover:bg-gray-700 rounded"
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
                <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-gray-800 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900">
                  <span className="text-sm text-gray-700 dark:text-gray-300">Add Tag</span>
                  <UserPlus size={20} className="text-gray-800 dark:text-gray-200" />
                </div>

                {/* Advanced Settings Accordion */}
                <div className="border-b border-gray-100 dark:border-gray-800">
                  <div
                    className="flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900"
                    onClick={() => setIsAdvancedSettingsOpen(!isAdvancedSettingsOpen)}
                  >
                    <span className="text-sm text-gray-800 dark:text-gray-200 font-medium">Advanced Settings</span>
                    {isAdvancedSettingsOpen ? <ChevronUp size={20} className="text-gray-600 dark:text-gray-400" /> : <ChevronDown size={20} className="text-gray-600 dark:text-gray-400" />}
                  </div>
                  {isAdvancedSettingsOpen && (
                    <div className="px-4 pb-4 flex flex-col gap-4">
                      <div className="flex flex-col gap-2">
                        <div className="flex items-center justify-between">
                          <span className="text-sm text-gray-800 dark:text-gray-200">Hide like and view counts on this post</span>
                          <div className="relative inline-flex items-center cursor-pointer" onClick={() => setHideLikes(!hideLikes)}>
                            <input type="checkbox" className="sr-only peer" checked={hideLikes} readOnly />
                            <div className="w-11 h-6 bg-gray-200 dark:bg-gray-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                          </div>
                        </div>
                        <p className="text-xs text-gray-500 dark:text-gray-400">
                          Only you will see the total number of likes and views on this post. You can change this later by going to the ... menu at the top of the post. To hide like counts on other people's posts, go to your account settings. <span className="text-blue-500 cursor-pointer">Learn more</span>
                        </p>
                      </div>

                      <div className="flex flex-col gap-2">
                        <div className="flex items-center justify-between">
                          <span className="text-sm text-gray-800 dark:text-gray-200">Turn off commenting</span>
                          <div className="relative inline-flex items-center cursor-pointer" onClick={() => setTurnOffCommenting(!turnOffCommenting)}>
                            <input type="checkbox" className="sr-only peer" checked={turnOffCommenting} readOnly />
                            <div className="w-11 h-6 bg-gray-200 dark:bg-gray-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                          </div>
                        </div>
                        <p className="text-xs text-gray-500 dark:text-gray-400">
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
