import React, { useState, useRef, useEffect } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import api from '../lib/api';
import { Image, Images, Video, X, ArrowLeft, Maximize2, Search, Copy, ZoomIn, Plus, ChevronLeft, ChevronRight, MapPin, UserPlus, ChevronDown, ChevronUp, Smile, Sun, Moon, Droplet, Thermometer, Cloud, Circle, Sliders, Megaphone } from 'lucide-react';
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
  const navigate = useNavigate();
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
  const [showVendorNotValidated, setShowVendorNotValidated] = useState(false);
  const [allUsers, setAllUsers] = useState([]);
  const [isLoadingAllUsers, setIsLoadingAllUsers] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  const POPULAR_EMOJIS = ['😂', '😮', '😍', '😢', '👏', '🔥', '🎉', '💯', '❤️', '🤣', '🥰', '😘', '😭', '😊'];

  // UI State
  const [showRatioMenu, setShowRatioMenu] = useState(false);
  const [showZoomSlider, setShowZoomSlider] = useState(false);
  const [showMultiSelect, setShowMultiSelect] = useState(false);
  const [activeTab, setActiveTab] = useState('filters'); // 'filters', 'adjustments'

  const ADJUSTMENT_ICONS = {
    'Brightness': Sun,
    'Contrast': Moon,
    'Saturation': Droplet,
    'Temperature': Thermometer,
    'Fade': Cloud,
    'Vignette': Circle
  };

  const fileInputRef = useRef(null);
  const cropContainerRef = useRef(null);
  const [overlaySize, setOverlaySize] = useState({ w: 0, h: 0 });
  const editContainerRef = useRef(null);
  const [editBoxSize, setEditBoxSize] = useState({ w: 0, h: 0 });
  const coverInputRef = useRef(null);
  const trimTrackRef = useRef(null);
  const [dragHandle, setDragHandle] = useState(null);
  const editVideoRef = useRef(null);
  const shareContainerRef = useRef(null);
  const [shareBoxSize, setShareBoxSize] = useState({ w: 0, h: 0 });

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

  useEffect(() => {
    if (step !== 'crop') return;
    const el = cropContainerRef.current;
    if (!el || !currentMedia) return;
    const compute = () => {
      const cw = el.clientWidth;
      const ch = el.clientHeight;
      const videoAspect = currentMedia.originalAspect || 1;
      let vw, vh;
      if (cw / ch > videoAspect) {
        vh = ch;
        vw = vh * videoAspect;
      } else {
        vw = cw;
        vh = vw / videoAspect;
      }
      const a = currentMedia.aspect || 1;
      let w = vw;
      let h = w / a;
      if (h > vh) {
        h = vh;
        w = h * a;
      }
      setOverlaySize({ w, h });
    };
    compute();
    const ro = new ResizeObserver(compute);
    ro.observe(el);
    return () => ro.disconnect();
  }, [step, currentMedia]);

  useEffect(() => {
    if (step !== 'share') return;
    const el = shareContainerRef.current;
    if (!el || !currentMedia) return;
    const compute = () => {
      const cw = el.clientWidth;
      const ch = el.clientHeight;
      const a = currentMedia.aspect || 1;
      let w = cw;
      let h = w / a;
      if (h > ch) {
        h = ch;
        w = h * a;
      }
      setShareBoxSize({ w, h });
    };
    compute();
    const ro = new ResizeObserver(compute);
    ro.observe(el);
    return () => ro.disconnect();
  }, [step, currentMedia]);

  useEffect(() => {
    if (step !== 'edit') return;
    const el = editContainerRef.current;
    if (!el || !currentMedia) return;
    const compute = () => {
      const cw = el.clientWidth;
      const ch = el.clientHeight;
      const a = currentMedia.aspect || 1;
      let w = cw;
      let h = w / a;
      if (h > ch) {
        h = ch;
        w = h * a;
      }
      setEditBoxSize({ w, h });
    };
    compute();
    const ro = new ResizeObserver(compute);
    ro.observe(el);
    return () => ro.disconnect();
  }, [step, currentMedia]);

  useEffect(() => {
    if (step !== 'edit') return;
    if (!currentMedia || currentMedia.type !== 'video') return;
    const v = editVideoRef.current;
    if (!v) return;
    const s = currentMedia.trimStart || 0;
    const d = currentMedia.duration || 0;
    const end = currentMedia.trimEnd && currentMedia.trimEnd > 0 ? currentMedia.trimEnd : d;
    try {
      if (v.currentTime < s || (end > 0 && v.currentTime > end)) {
        v.currentTime = s;
      }
    } catch { void 0; }
  }, [step, currentMedia && currentMedia.trimStart, currentMedia && currentMedia.trimEnd]);

  const handleFileSelect = (e) => {
    const files = Array.from(e.target.files);
    if (files && files.length > 0) {
      handleFiles(files);
    }
    e.target.value = '';
  };

  const handleFiles = async (files) => {
    // Process files immediately
    const validFiles = files.filter(file => {
      if (postType === 'post') return file.type.startsWith('image/');
      if (postType === 'reel') return file.type.startsWith('video/');
      return file.type.startsWith('image/') || file.type.startsWith('video/');
    });

    if (validFiles.length === 0) return;

    const newMedia = await Promise.all(validFiles.map(async (file) => {
      const url = URL.createObjectURL(file);
      if (file.type.startsWith('image/')) {
        let aspect = 1;
        let originalAspect = null;
        try {
          const img = await createImage(url);
          originalAspect = img.width / img.height;
          aspect = originalAspect;
        } catch {
          aspect = 1;
          originalAspect = null;
        }
        return {
          id: Math.random().toString(36).substr(2, 9),
          url,
          type: 'image',
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
      } else {
        const video = document.createElement('video');
        video.src = url;
        await new Promise((resolve) => {
          video.onloadedmetadata = resolve;
        });
        const originalAspect = (video.videoWidth && video.videoHeight) ? (video.videoWidth / video.videoHeight) : 1;
        const duration = isFinite(video.duration) ? video.duration : 0;
        return {
          id: Math.random().toString(36).substr(2, 9),
          url,
          type: 'video',
          crop: { x: 0, y: 0 },
          zoom: 1,
          aspect: originalAspect || 1,
          originalAspect: originalAspect || 1,
          duration,
          coverUrl: null,
          thumbnails: null,
          trimStart: 0,
          trimEnd: duration || 0,
          soundOn: true,
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
      }
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

  useEffect(() => {
    if (step === 'edit' && currentMedia?.type === 'video') {
      setActiveTab('video');
    }
  }, [step, currentMedia]);

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
      if (media.some(m => m.type === 'video')) {
        const newMedia = await Promise.all(media.map(async (item) => {
          try {
            const croppedUrl = await getCroppedImg(item.url, item.croppedAreaPixels);
            return { ...item, croppedUrl };
          } catch {
            return { ...item, croppedUrl: item.url };
          }
        }));
        setMedia(newMedia);
        setStep('edit');
      } else {
        const newMedia = await Promise.all(media.map(async (item) => {
          try {
            const croppedUrl = await getCroppedImg(item.url, item.croppedAreaPixels);
            return { ...item, croppedUrl };
          } catch {
            return { ...item, croppedUrl: item.url };
          }
        }));
        setMedia(newMedia);
        setStep('edit');
      }
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

        // Helper to stringify aspect ratio label
        const getAspectRatioLabel = (a) => {
          if (!a) return 'original';
          if (Math.abs(a - 1) < 0.001) return '1:1';
          if (Math.abs(a - (4 / 5)) < 0.001) return '4:5';
          if (Math.abs(a - (16 / 9)) < 0.001) return '16:9';
          if (Math.abs(a - (9 / 16)) < 0.001) return '9:16';
          return 'custom';
        };

        // Upload media and prepare array
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

          const uploadResponse = await api.post('https://bsmart.asynk.store/api/upload', formData, {
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

          // Upload selected thumbnail only (video)
          let uploadedThumbs = null;
          let thumbnailTime = 0;
          if (item.type === 'video') {
            const thumbs = item.thumbnails || [];
            const cover = item.coverUrl;
            if (cover) {
              const thumbForm = new FormData();
              const imgBlob = await (async () => {
                const img = await fetch(cover);
                return await img.blob();
              })();
              const tFile = new File([imgBlob], `thumb_${Date.now()}.jpg`, { type: 'image/jpeg' });
              // API supports single file param
              thumbForm.append('file', tFile);
              try {
                const thumbRes = await api.post('https://bsmart.asynk.store/api/upload/thumbnail', thumbForm, {
                  headers: { 'Content-Type': 'multipart/form-data' }
                });
                uploadedThumbs = thumbRes.data?.thumbnails || null;
              } catch {
                uploadedThumbs = null;
              }
              const count = thumbs.length;
              const idx = Math.max(0, thumbs.findIndex(t => t === cover));
              const dur = item.duration || 0;
              thumbnailTime = (count > 1 && dur > 0) ? (idx * dur) / (count - 1) : 0;
            }
          }

          const baseObj = {
            fileName: serverFileName || fileName,
            type: item.type === 'video' ? 'video' : 'image',
            fileUrl: fileUrl,
            crop: {
              mode: "original",
              aspect_ratio: getAspectRatioLabel(item.aspect || item.originalAspect || 1),
              zoom: item.zoom,
              x: item.crop.x,
              y: item.crop.y
            },
            timing: item.type === 'video' ? { start: item.trimStart || 0, end: item.trimEnd || item.duration || 0 } : undefined,
            thumbnail: uploadedThumbs || undefined,
            "thumbail-time": item.type === 'video' ? thumbnailTime : undefined,
            videoLength: item.type === 'video' ? (item.duration || 0) : undefined,
            totalLenght: item.type === 'video' ? (item.duration || 0) : undefined,
            "finalLength-start": item.type === 'video' ? (item.trimStart || 0) : undefined,
            "finallength-end": item.type === 'video' ? (item.trimEnd || item.duration || 0) : undefined,
            finalLength: item.type === 'video' ? Math.max(0, (item.trimEnd || item.duration || 0) - (item.trimStart || 0)) : undefined,
            finallength: item.type === 'video' ? Math.max(0, (item.trimEnd || item.duration || 0) - (item.trimStart || 0)) : undefined
          };
          
          if (item.type !== 'video') {
            baseObj.filter = {
              name: item.filter,
              css: filterCss
            };
            baseObj.adjustments = {
              brightness: item.adjustments.brightness,
              contrast: item.adjustments.contrast,
              saturation: item.adjustments.saturate,
              temperature: item.adjustments.sepia,
              fade: item.adjustments.opacity,
              vignette: item.adjustments.vignette
            };
          }
          
          return baseObj;
        }));

        // Extract hashtags from caption
        const hashtags = caption.match(/#[a-zA-Z0-9_]+/g) || [];

        if (postType === 'reel') {
          const payload = {
            caption,
            location,
            media: processedMedia.filter(m => m.type === 'video'),
            tags: hashtags,
            people_tags: tags.map(t => ({
              user_id: t.user.id,
              username: t.user.username,
              x: t.x,
              y: t.y
            })),
            hide_likes_count: hideLikes,
            turn_off_commenting: turnOffCommenting
          };
          await api.post('https://bsmart.asynk.store/api/posts/reels', payload);
          setShowSuccess(true);
        } else {
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
        }

        if (!showSuccess) {
          handleClose();
          setMedia([]);
          setCaption('');
          setLocation('');
          setTags([]);
          alert("Post shared successfully!");
        }

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
      const { data } = await api.get('https://bsmart.asynk.store/api/users');
      let usersRaw = Array.isArray(data) ? data : (data.users || []);
      const users = usersRaw.map(item => item.user || item);
      if (query && query.trim()) {
        const q = query.trim().toLowerCase();
        usersRaw = users.filter(u => (u.username || '').toLowerCase().includes(q) || (u.full_name || '').toLowerCase().includes(q));
      }
      const mapped = (query && query.trim() ? usersRaw : users).map(u => ({
        id: u.id,
        username: u.username,
        avatar_url: u.avatar_url || '',
        full_name: u.full_name || ''
      }));
      setSearchResults(mapped);
    } catch {
      setSearchResults([]);
    } finally {
      setIsSearchingUsers(false);
    }
  };

  useEffect(() => {
    if (step !== 'share') return;
    const loadAll = async () => {
      setIsLoadingAllUsers(true);
      try {
        const { data } = await api.get('https://bsmart.asynk.store/api/users');
        const usersRaw = Array.isArray(data) ? data : (data.users || []);
        const users = usersRaw.map(item => item.user || item);
        const mapped = users.map(u => ({
          id: u.id,
          username: u.username,
          avatar_url: u.avatar_url || '',
          full_name: u.full_name || ''
        }));
        setAllUsers(mapped);
      } catch {
        setAllUsers([]);
      } finally {
        setIsLoadingAllUsers(false);
      }
    };
    loadAll();
  }, [step]);

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

  const formatDuration = (d) => {
    if (!d || !isFinite(d)) return '00:00';
    const m = Math.floor(d / 60);
    const s = Math.floor(d % 60);
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  };

  useEffect(() => {
    if (step !== 'cover' && step !== 'edit') return;
    const item = currentMedia;
    if (!item || item.type !== 'video') return;
    if (item.thumbnails && Array.isArray(item.thumbnails)) return;
    const v = document.createElement('video');
    v.crossOrigin = 'anonymous';
    v.src = item.croppedUrl || item.url;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    const run = async () => {
      await new Promise(res => { v.onloadedmetadata = res; });
      const duration = isFinite(v.duration) ? v.duration : 0;
      const frames = [];
      const count = 8;
      const width = 240;
      const height = 240;
      canvas.width = width;
      canvas.height = height;
      for (let i = 0; i < count; i++) {
        const t = duration > 0 ? (i * duration) / (count - 1) : 0;
        await new Promise(res => {
          v.currentTime = t;
          v.onseeked = res;
        });
        ctx.drawImage(v, 0, 0, width, height);
        const url = canvas.toDataURL('image/jpeg', 0.9);
        frames.push(url);
      }
      updateCurrentMedia({ thumbnails: frames, coverUrl: frames[0] });
    };
    run();
  }, [step, currentMedia, updateCurrentMedia]);

  useEffect(() => {
    if (step !== 'crop') return;
    const item = currentMedia;
    if (!item || item.type !== 'video') return;
    if (item.coverUrl) return;
    const v = document.createElement('video');
    v.crossOrigin = 'anonymous';
    v.src = item.url;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    const run = async () => {
      await new Promise((resolve) => {
        v.onloadedmetadata = resolve;
      });
      const w = v.videoWidth || 640;
      const h = v.videoHeight || 360;
      canvas.width = w;
      canvas.height = h;
      await new Promise((res) => {
        v.currentTime = 0;
        v.onseeked = res;
      });
      ctx.drawImage(v, 0, 0, w, h);
      const url = canvas.toDataURL('image/jpeg', 0.9);
      updateCurrentMedia({ coverUrl: url });
    };
    run();
  }, [step, currentMedia, updateCurrentMedia]);

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
              <h2 className="font-semibold text-base text-center dark:text-white flex-1">{step === 'crop' ? 'Crop' : step === 'cover' ? 'Cover' : step === 'edit' ? 'Edit' : 'Create new post'}</h2>
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
            className={`flex-1 relative flex flex-col items-center justify-center p-8 transition-colors ${isDragging ? 'bg-blue-50 dark:bg-blue-900/20' : 'bg-white dark:bg-[#262626]'}`}
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
            <div className="md:hidden absolute left-0 right-0 bottom-6 flex justify-center">
              <div className="backdrop-blur-md bg-black/40 dark:bg-black/40 border border-white/10 rounded-2xl shadow-xl px-2 py-2 w-[92%] max-w-sm text-white flex items-center justify-around">
                <button
                  onClick={() => setPostType('post')}
                  className={`flex items-center gap-2 px-3 py-2 rounded-xl ${postType === 'post' ? 'bg-white/20' : 'hover:bg-white/10'}`}
                >
                  <Image size={18} className="text-purple-400" />
                  <span className="text-xs font-semibold">Post</span>
                </button>
                <button
                  onClick={() => setPostType('reel')}
                  className={`flex items-center gap-2 px-3 py-2 rounded-xl ${postType === 'reel' ? 'bg-white/20' : 'hover:bg-white/10'}`}
                >
                  <Video size={18} className="text-pink-400" />
                  <span className="text-xs font-semibold">Reel</span>
                </button>
                {userObject?.role === 'vendor' && (
                  <button
                    onClick={() => {
                      if (!userObject.vendor_validated) {
                        setShowVendorNotValidated(true);
                      } else {
                        onClose();
                        navigate('/ads');
                      }
                    }}
                    className="flex items-center gap-2 px-3 py-2 rounded-xl hover:bg-white/10"
                  >
                    <Megaphone size={18} className="text-blue-400" />
                    <span className="text-xs font-semibold">Ad</span>
                  </button>
                )}
              </div>
            </div>
          </div>
        ) : step === 'crop' ? (
          <div className="flex-1 bg-[#f0f0f0] dark:bg-[#121212] relative flex items-center justify-center overflow-hidden">
            {currentMedia && (
              <div className="relative w-full h-full" ref={cropContainerRef}>
                {currentMedia.type === 'video' ? (
                  <>
                    <video
                      src={currentMedia.url}
                      className="absolute inset-0 w-full h-full object-contain"
                      autoPlay
                      muted
                      playsInline
                      controls
                    />
                    <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                      <div
                        className="rounded"
                        style={{
                          width: overlaySize.w,
                          height: overlaySize.h,
                          border: '2px solid rgba(255,255,255,0.85)',
                          boxShadow: '0 0 0 9999px rgba(0,0,0,0.4)'
                        }}
                      />
                    </div>
                  </>
                ) : (
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
                )}
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
                    <button onClick={() => setAspect(9 / 16)} className={`flex items-center gap-3 px-4 py-3 text-sm font-medium hover:bg-white/10 ${currentMedia.aspect === 9 / 16 ? 'text-white' : 'text-gray-400'}`}><span className="w-3 h-5 border-2 border-current rounded-sm"></span> 9:16</button>
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
                          <img src={item.type === 'video' ? (item.coverUrl || item.url) : item.url} className="w-full h-full object-cover" alt="" />
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
        ) : step === 'cover' ? (
          <div className="flex-1 flex lg:flex-row flex-col lg:overflow-hidden overflow-y-auto overflow-x-hidden">
            <div className="relative bg-[#f0f0f0] dark:bg-[#121212] flex items-center justify-center w-full flex-1 h-auto">
              {currentMedia && currentMedia.type === 'video' && (
                <div className="relative w-full h-full flex items-center justify-center">
                  <img
                    src={currentMedia.coverUrl || (currentMedia.thumbnails && currentMedia.thumbnails[0]) || ''}
                    className="max-w-full max-h-full object-contain"
                    alt=""
                  />
                  {currentMedia.duration !== undefined && (
                    <div className="absolute bottom-3 left-3 bg-black/70 text-white text-xs px-2 py-1 rounded">
                      {formatDuration(currentMedia.duration)}
                    </div>
                  )}
                </div>
              )}
            </div>
            <div className="bg-white dark:bg-black border-l border-gray-200 dark:border-gray-800 flex flex-col lg:w-[340px] w-full min-w-[340px] flex-none">
              <div className="p-4">
                <div className="flex gap-3 overflow-x-auto py-1">
                  {(currentMedia?.thumbnails || []).map((thumb, idx) => (
                    <button
                      key={idx}
                      onClick={() => updateCurrentMedia({ coverUrl: thumb })}
                      className={`relative flex-none w-16 h-16 rounded-lg overflow-hidden ring-2 ${currentMedia.coverUrl === thumb ? 'ring-[#0095f6]' : 'ring-transparent'}`}
                    >
                      <img src={thumb} className="w-full h-full object-cover" alt="" />
                    </button>
                  ))}
                </div>
                {!currentMedia?.thumbnails && (
                  <div className="mt-2 flex items-center gap-2">
                    <div className="w-4 h-4 border-2 border-gray-400 dark:border-gray-500 border-t-transparent rounded-full animate-spin"></div>
                    <span className="text-xs text-gray-500 dark:text-gray-400">Generating thumbnails...</span>
                  </div>
                )}
              </div>
            </div>
          </div>
        ) : step === 'edit' ? (
          /* EDIT STEP */
          <div className="flex-1 flex lg:flex-row flex-col lg:overflow-hidden overflow-y-auto overflow-x-hidden">
            {/* Left: Image Preview */}
            <div ref={editContainerRef} className="relative bg-[#f0f0f0] dark:bg-[#121212] flex items-center justify-center w-full flex-1 h-auto">
              {currentMedia && (
                currentMedia.type === 'video' ? (
                  <div style={{ width: editBoxSize.w, height: editBoxSize.h }} className="overflow-hidden bg-black/10 rounded">
                      <video
                        src={currentMedia.croppedUrl || currentMedia.url}
                        className="w-full h-full object-cover transition-all duration-200"
                        controls
                        autoPlay
                        muted={!currentMedia.soundOn}
                        loop={false}
                        ref={editVideoRef}
                        onLoadedMetadata={(e) => {
                          e.currentTarget.currentTime = currentMedia.trimStart || 0;
                        }}
                        onSeeking={(e) => {
                          const v = e.currentTarget;
                          const s = currentMedia.trimStart || 0;
                          const d = currentMedia.duration || 0;
                          const end = currentMedia.trimEnd && currentMedia.trimEnd > 0 ? currentMedia.trimEnd : d;
                          if (v.currentTime < s) v.currentTime = s;
                          if (end > 0 && v.currentTime > end) v.currentTime = end;
                        }}
                        onSeeked={(e) => {
                          const v = e.currentTarget;
                          const s = currentMedia.trimStart || 0;
                          const d = currentMedia.duration || 0;
                          const end = currentMedia.trimEnd && currentMedia.trimEnd > 0 ? currentMedia.trimEnd : d;
                          if (v.currentTime < s) v.currentTime = s;
                          if (end > 0 && v.currentTime > end) v.currentTime = end;
                        }}
                        onTimeUpdate={(e) => {
                          const v = e.currentTarget;
                          const d = currentMedia.duration || 0;
                          const end = currentMedia.trimEnd && currentMedia.trimEnd > 0 ? currentMedia.trimEnd : d;
                          if (end > 0 && v.currentTime >= end) {
                            v.currentTime = currentMedia.trimStart || 0;
                          }
                        }}
                        onEnded={(e) => {
                          e.currentTarget.currentTime = currentMedia.trimStart || 0;
                          e.currentTarget.play();
                        }}
                      />
                  </div>
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
                {currentMedia?.type !== 'video' ? (
                  <>
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
                  </>
                ) : (
                  <button
                    className={`flex-1 py-3 text-sm font-semibold transition-colors ${activeTab === 'video' ? 'text-black dark:text-white border-b border-black dark:border-white' : 'text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'}`}
                    onClick={() => setActiveTab('video')}
                  >
                    Video
                  </button>
                )}
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
                          <img
                            src={currentMedia.croppedUrl || currentMedia.url}
                            className="w-full h-full object-cover"
                            style={{ filter: filter.style }}
                            alt={filter.name}
                          />
                        </div>
                        <span className={`text-xs font-semibold ${currentMedia.filter === filter.name ? 'text-[#0095f6]' : 'text-gray-500 dark:text-gray-400'}`}>
                          {filter.name}
                        </span>
                      </div>
                    ))}
                  </div>
                ) : activeTab === 'adjustments' ? (
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
                            disabled={currentMedia?.type === 'video'}
                          />
                          <span className="text-xs font-mono w-8 text-right text-gray-500 dark:text-gray-400">
                            {currentMedia.adjustments[adj.property] || 0}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  (currentMedia?.thumbnails && currentMedia.duration !== undefined) ? (
                  <div className="flex flex-col gap-6 pb-4">
                    <div>
                      <div className="flex items-center justify-between mb-2">
                        <div className="text-sm font-semibold dark:text-white">Cover photo</div>
                        <button className="text-sm font-semibold text-[#0095f6]" onClick={() => coverInputRef.current?.click()}>Select From Computer</button>
                        <input ref={coverInputRef} type="file" accept="image/*" className="hidden" onChange={(e) => {
                          const f = e.target.files?.[0];
                          if (!f) return;
                          const url = URL.createObjectURL(f);
                          updateCurrentMedia({ coverUrl: url });
                          e.target.value = '';
                        }} />
                      </div>
                      <div className="grid grid-cols-3 gap-3">
                        {(currentMedia?.thumbnails || []).map((thumb, idx) => (
                          <button
                            key={idx}
                            onClick={() => updateCurrentMedia({ coverUrl: thumb })}
                            className={`relative w-full aspect-square rounded overflow-hidden border-2 ${currentMedia.coverUrl === thumb ? 'border-[#0095f6]' : 'border-transparent'}`}
                          >
                            <img src={thumb} className="w-full h-full object-cover" alt="" />
                          </button>
                        ))}
                      </div>
                    </div>
                    <div>
                      <div className="text-sm font-semibold mb-2 dark:text-white">Trim</div>
                      {currentMedia?.thumbnails ? (
                        <div
                          ref={trimTrackRef}
                          className="relative w-full h-20 rounded bg-black/10 dark:bg-white/5 overflow-visible select-none"
                          onMouseMove={(e) => {
                            if (!dragHandle) return;
                            const rect = trimTrackRef.current.getBoundingClientRect();
                            const ratio = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
                            const t = ratio * (currentMedia.duration || 0);
                            if (dragHandle === 'start') {
                              const val = Math.min(t, (currentMedia.trimEnd || 0) - 0.1);
                              updateCurrentMedia({ trimStart: Math.max(0, val) });
                            } else {
                              const val = Math.max(t, (currentMedia.trimStart || 0) + 0.1);
                              updateCurrentMedia({ trimEnd: Math.min(currentMedia.duration || 0, val) });
                            }
                          }}
                          onMouseLeave={() => setDragHandle(null)}
                          onMouseUp={() => setDragHandle(null)}
                        >
                          <div className="absolute inset-0 flex">
                            {(currentMedia.thumbnails || []).map((thumb, idx) => (
                              <img key={idx} src={thumb} className="h-full flex-1 object-cover" alt="" />
                            ))}
                          </div>
                          <div className="absolute inset-0">
                            {(() => {
                              const dur = currentMedia.duration || 0;
                              const s = (currentMedia.trimStart || 0) / (dur || 1);
                              const e = (currentMedia.trimEnd || 0) / (dur || 1);
                              const left = `${s * 100}%`;
                              return (
                                <>
                                  <div className="absolute top-0 bottom-0 bg-black/40" style={{ left: 0, right: `calc(100% - ${left})` }} />
                                  <div className="absolute top-0 bottom-0 bg-black/40" style={{ left: `${e * 100}%`, right: 0 }} />
                                  <div
                                    className="absolute top-0 bottom-0 w-3 bg-white rounded-lg cursor-ew-resize ring-1 ring-black/30"
                                    style={{ left }}
                                    onMouseDown={() => setDragHandle('start')}
                                  />
                                  <div
                                    className="absolute top-0 bottom-0 w-3 bg-white rounded-lg cursor-ew-resize ring-1 ring-black/30"
                                    style={{ left: `calc(${e * 100}% - 0.5rem)` }}
                                    onMouseDown={() => setDragHandle('end')}
                                  />
                                  <div className="absolute -top-6 z-20 text-xs font-mono text-white px-1.5 py-0.5 rounded bg-black/60 pointer-events-none" style={{ left: `calc(${s * 100}% - 1.5rem)` }}>
                                    {formatDuration(currentMedia.trimStart || 0)}
                                  </div>
                                  <div className="absolute -top-6 z-20 text-xs font-mono text-white px-1.5 py-0.5 rounded bg-black/60 pointer-events-none" style={{ left: `calc(${e * 100}% - 1.5rem)` }}>
                                    {formatDuration(currentMedia.trimEnd || 0)}
                                  </div>
                                </>
                              );
                            })()}
                          </div>
                          {(() => {
                            const dur = currentMedia.duration || 0;
                            const endVal = (currentMedia.trimEnd && currentMedia.trimEnd > 0) ? currentMedia.trimEnd : dur;
                            const startVal = currentMedia.trimStart || 0;
                            const midVal = (startVal + endVal) / 2;
                            return (
                              <div className="absolute -bottom-6 left-1/2 -translate-x-1/2 text-xs font-semibold text-gray-200">
                                {formatDuration(midVal)}
                              </div>
                            );
                          })()}
                        </div>
                      ) : null}
                    </div>
                    <div className="flex items-center justify-between mt-2">
                      <span className="text-sm font-semibold dark:text-white">Sound on</span>
                      <label className="relative inline-flex items-center cursor-pointer">
                        <input
                          type="checkbox"
                          className="sr-only peer"
                          checked={currentMedia.soundOn}
                          onChange={(e) => updateCurrentMedia({ soundOn: e.target.checked })}
                        />
                        <div className="w-11 h-6 bg-gray-200 dark:bg-gray-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                      </label>
                    </div>
                  </div>
                  ) : (
                    <div className="flex items-center justify-center py-16">
                      <div className="w-8 h-8 border-2 border-[#0095f6] border-t-transparent rounded-full animate-spin"></div>
                    </div>
                  )
                )}
              </div>
            </div>
          </div>
        ) : (
          /* SHARE STEP */
          <div className="flex-1 flex flex-col md:flex-row lg:overflow-hidden overflow-y-auto overflow-x-hidden">
            {/* Left: Final Image Preview */}
            <div className="relative bg-[#f0f0f0] dark:bg-[#121212] flex items-center justify-center select-none w-full h-auto md:flex-[2]">
              {currentMedia && (
                <div ref={shareContainerRef} className="relative w-full h-full flex items-center justify-center" onClick={handleImageClick}>
                  {currentMedia.type === 'video' ? (
                    <div style={{ width: shareBoxSize.w, height: shareBoxSize.h }} className="overflow-hidden bg-black rounded">
                      <video
                        src={currentMedia.croppedUrl || currentMedia.url}
                        className="w-full h-full object-cover"
                        controls={false}
                        autoPlay
                        muted={!currentMedia.soundOn}
                        onLoadedMetadata={(e) => {
                          e.currentTarget.currentTime = currentMedia.trimStart || 0;
                        }}
                        onTimeUpdate={(e) => {
                          const v = e.currentTarget;
                          const end = currentMedia.trimEnd || 0;
                          if (end > 0 && v.currentTime > end) {
                            v.pause();
                            v.currentTime = end;
                          }
                        }}
                      />
                    </div>
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
                      <div className="max-h-48 overflow-y-auto scrollbar-hide">
                        {isSearchingUsers ? (
                          <div className="p-4 text-center text-gray-400 text-xs">Searching...</div>
                        ) : searchResults.length > 0 ? (
                          searchResults.map(user => (
                            <div
                              key={user.id}
                              className="flex items-center gap-3 p-3 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer"
                              onClick={(e) => { e.stopPropagation(); handleTagUser(user); }}
                            >
                              <div className="w-8 h-8 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden flex-shrink-0 flex items-center justify-center">
                                {user.avatar_url ? (
                                  <img src={user.avatar_url} className="w-full h-full object-cover" alt={user.username} />
                                ) : (
                                  <span className="text-xs font-semibold text-gray-800 dark:text-white">
                                    {(user.username || '').slice(0, 1).toUpperCase()}
                                  </span>
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
            <div className="flex-1 bg-white dark:bg-black border-t md:border-t-0 md:border-l border-gray-200 dark:border-gray-800 flex flex-col w-full md:w-auto md:min-w-[340px] overflow-y-auto scrollbar-hide">
              {/* User Info */}
              <div className="flex items-center gap-3 p-4">
                <div className="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden flex items-center justify-center">
                  {userObject?.avatar_url ? (
                    <img src={userObject.avatar_url} className="w-full h-full object-cover" alt={userObject.username} />
                  ) : (
                    <span className="text-xs font-semibold text-gray-800 dark:text-white">
                      {(userObject?.username || 'U').slice(0, 1).toUpperCase()}
                    </span>
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
                <div
                  className="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-gray-800 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900"
                  onClick={() => {
                    setTagCoordinates({ x: 85, y: 85 });
                    setShowTagSearch(true);
                    setSearchQuery('');
                    fetchUsers('');
                  }}
                >
                  <span className="text-sm text-gray-700 dark:text-gray-300">Add Tag</span>
                  <UserPlus size={20} className="text-gray-800 dark:text-gray-200" />
                </div>
                <div
                  className="px-4 py-2 max-h-56 overflow-y-auto flex flex-col gap-2 pr-2"
                  style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
                >
                  {isLoadingAllUsers ? (
                    <div className="text-xs text-gray-500 dark:text-gray-400">Loading users...</div>
                  ) : allUsers.length > 0 ? (
                    allUsers.map(u => (
                      <div
                        key={u.id}
                        className="flex items-center gap-3 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900 rounded-md px-2 py-1"
                        onClick={() => {
                          setTagCoordinates({ x: 85, y: 85 });
                          handleTagUser(u);
                        }}
                      >
                        <div className="w-8 h-8 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden flex-shrink-0 flex items-center justify-center">
                          {u.avatar_url ? (
                            <img src={u.avatar_url} className="w-full h-full object-cover" alt={u.username} />
                          ) : (
                            <span className="text-xs font-semibold text-gray-800 dark:text-white">
                              {(u.username || '').slice(0, 1).toUpperCase()}
                            </span>
                          )}
                        </div>
                        <div className="flex flex-col overflow-hidden">
                          <span className="text-sm font-semibold truncate dark:text-white">{u.username}</span>
                          <span className="text-xs text-gray-500 dark:text-gray-400 truncate">{u.full_name}</span>
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-xs text-gray-500 dark:text-gray-400">No users found</div>
                  )}
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
        accept={postType === 'post' ? 'image/*' : postType === 'reel' ? 'video/*' : 'image/*,video/*'}
        onChange={handleFileSelect}
      />
      {showVendorNotValidated && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4 md:hidden">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">
              Vendor verification pending
            </h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">
              Your vendor account is not yet validated. Please refresh this page or wait 2–3 working days for verification before uploading ads.
            </p>
            <div className="flex justify-center">
              <button
                onClick={() => setShowVendorNotValidated(false)}
                className="px-4 py-2.5 rounded-lg bg-insta-pink text-white font-medium hover:bg-insta-purple transition-colors"
              >
                OK
              </button>
            </div>
          </div>
        </div>
      )}
      {showSuccess && (
        <div className="fixed inset-0 z-[80] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-sm shadow-2xl border border-gray-100 dark:border-gray-800">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2 text-center">
              Reel uploaded successfully
            </h3>
            <p className="text-gray-500 dark:text-gray-400 text-sm mb-6 text-center">
              Your reel has been created. You can close this window or continue editing.
            </p>
            <div className="flex justify-center gap-3">
              <button
                onClick={() => {
                  setShowSuccess(false);
                  handleClose();
                }}
                className="px-4 py-2.5 rounded-lg bg-insta-pink text-white font-medium hover:bg-insta-purple transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CreatePostModal;
