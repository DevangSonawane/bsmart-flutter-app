import React, { useState } from 'react';
import { X, ChevronLeft, ChevronRight, Heart, Send } from 'lucide-react';

const StoryViewer = ({ initialStoryIndex, stories, onClose }) => {
  const [currentIndex, setCurrentIndex] = useState(initialStoryIndex);

  const currentStory = stories[currentIndex];

  const handleNext = (e) => {
    e.stopPropagation();
    if (currentIndex < stories.length - 1) {
      setCurrentIndex(prev => prev + 1);
    } else {
        onClose();
    }
  };

  const handlePrev = (e) => {
    e.stopPropagation();
    if (currentIndex > 0) {
      setCurrentIndex(prev => prev - 1);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] bg-black flex items-center justify-center animate-in fade-in duration-200">
      {/* Top Controls */}
      <div className="absolute top-0 left-0 right-0 p-4 flex justify-between items-start z-10 bg-gradient-to-b from-black/50 to-transparent h-24">
        <div className="flex items-center gap-3 text-white">
          <div className="w-8 h-8 rounded-full border border-white/50 overflow-hidden">
             <img src={`https://i.pravatar.cc/150?u=${currentStory.username}`} alt={currentStory.username} className="w-full h-full object-cover" />
          </div>
          <div>
            <div className="flex items-center gap-2">
                 <span className="font-semibold text-sm">{currentStory.username}</span>
                 <span className="text-white/60 text-xs">12 h</span>
            </div>
          </div>
        </div>
        
        <button onClick={onClose} className="text-white">
          <X size={28} strokeWidth={2.5} />
        </button>
      </div>

      {/* Main Content Area */}
      <div className="relative w-full h-full md:w-[400px] md:h-[85vh] flex items-center justify-center">
        
        {/* Navigation Arrows (Desktop) */}
        {currentIndex > 0 && (
          <button 
            onClick={handlePrev}
            className="absolute -left-16 top-1/2 -translate-y-1/2 bg-white/10 hover:bg-white/20 p-2 rounded-full text-white hidden md:block transition-colors"
          >
            <ChevronLeft size={24} />
          </button>
        )}
        
        {/* Story Image */}
        <div className="w-full h-full relative bg-gray-900 md:rounded-xl overflow-hidden" onClick={handleNext}>
             {/* Progress Bar */}
             <div className="absolute top-2 left-2 right-2 flex gap-1 z-10">
                <div className="h-0.5 flex-1 bg-white/30 rounded-full overflow-hidden">
                    <div className="h-full bg-white w-full animate-[progress_5s_linear]" />
                </div>
             </div>

            <img 
                src={currentStory.imageUrl || `https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=500&auto=format&fit=crop&q=60`} 
                alt="Story" 
                className="w-full h-full object-cover"
            />
            
            {/* Bottom Actions */}
            <div className="absolute bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-black/60 to-transparent flex items-center gap-4">
                <input 
                    type="text" 
                    placeholder={`Reply to ${currentStory.username}...`} 
                    className="flex-1 bg-transparent border border-white/30 rounded-full px-4 py-2.5 text-white placeholder-white/70 focus:outline-none focus:border-white/60 text-sm backdrop-blur-sm"
                    onClick={(e) => e.stopPropagation()}
                />
                <button className="text-white p-1 hover:scale-110 transition-transform" onClick={(e) => e.stopPropagation()}>
                    <Heart size={28} />
                </button>
                <button className="text-white p-1 hover:scale-110 transition-transform" onClick={(e) => e.stopPropagation()}>
                    <Send size={28} />
                </button>
            </div>
        </div>

        {/* Next Arrow (Desktop) */}
        <button 
          onClick={handleNext}
          className="absolute -right-16 top-1/2 -translate-y-1/2 bg-white/10 hover:bg-white/20 p-2 rounded-full text-white hidden md:block transition-colors"
        >
          <ChevronRight size={24} />
        </button>

        {/* Side Previews (Desktop only decoration) */}
        <div className="absolute -right-[220px] top-1/2 -translate-y-1/2 w-[180px] h-[320px] opacity-40 scale-90 hidden lg:block pointer-events-none">
             {stories[currentIndex + 1] && (
                 <div className="w-full h-full bg-gray-800 rounded-xl overflow-hidden relative">
                    <div className="absolute inset-0 flex items-center justify-center">
                        <div className="w-12 h-12 rounded-full border-2 border-insta-pink p-[2px]">
                            <img src={`https://i.pravatar.cc/150?u=${stories[currentIndex + 1].username}`} className="w-full h-full rounded-full object-cover" />
                        </div>
                    </div>
                     <img src={stories[currentIndex + 1].imageUrl || `https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=500&auto=format&fit=crop&q=60`} className="w-full h-full object-cover opacity-50" />
                     <div className="absolute bottom-4 left-0 right-0 text-center text-white text-sm font-semibold">{stories[currentIndex + 1].username}</div>
                 </div>
             )}
        </div>
         <div className="absolute -left-[220px] top-1/2 -translate-y-1/2 w-[180px] h-[320px] opacity-40 scale-90 hidden lg:block pointer-events-none">
             {stories[currentIndex - 1] && (
                 <div className="w-full h-full bg-gray-800 rounded-xl overflow-hidden relative">
                     <div className="absolute inset-0 flex items-center justify-center">
                        <div className="w-12 h-12 rounded-full border-2 border-insta-pink p-[2px]">
                            <img src={`https://i.pravatar.cc/150?u=${stories[currentIndex - 1].username}`} className="w-full h-full rounded-full object-cover" />
                        </div>
                    </div>
                     <img src={stories[currentIndex - 1].imageUrl || `https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=500&auto=format&fit=crop&q=60`} className="w-full h-full object-cover opacity-50" />
                      <div className="absolute bottom-4 left-0 right-0 text-center text-white text-sm font-semibold">{stories[currentIndex - 1].username}</div>
                 </div>
             )}
        </div>
      </div>
    </div>
  );
};

export default StoryViewer;
