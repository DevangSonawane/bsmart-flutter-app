import React, { useState } from 'react';
import { Image, X } from 'lucide-react';

const CreatePost = () => {
  const [selectedImage, setSelectedImage] = useState(null);
  const [caption, setCaption] = useState('');

  const handleImageChange = (e) => {
    if (e.target.files && e.target.files[0]) {
      setSelectedImage(URL.createObjectURL(e.target.files[0]));
    }
  };

  return (
    <div className="bg-white min-h-screen pt-4 px-4 pb-20">
      <h2 className="text-xl font-bold mb-4 text-center">New Post</h2>
      
      {!selectedImage ? (
        <div className="w-full aspect-square bg-gray-100 rounded-lg flex flex-col items-center justify-center border-2 border-dashed border-gray-300">
          <Image size={48} className="text-gray-400 mb-2" />
          <label className="text-blue-500 font-semibold cursor-pointer">
            Select from Gallery
            <input type="file" className="hidden" accept="image/*" onChange={handleImageChange} />
          </label>
        </div>
      ) : (
        <div className="relative w-full aspect-square bg-black rounded-lg overflow-hidden">
          <img src={selectedImage} alt="Selected" className="w-full h-full object-contain" />
          <button 
            onClick={() => setSelectedImage(null)}
            className="absolute top-2 right-2 bg-black/50 p-1 rounded-full text-white"
          >
            <X size={20} />
          </button>
        </div>
      )}

      <div className="mt-4">
        <textarea
          className="w-full p-3 border border-gray-300 rounded-lg resize-none focus:outline-none focus:border-gray-500"
          rows="4"
          placeholder="Write a caption..."
          value={caption}
          onChange={(e) => setCaption(e.target.value)}
        ></textarea>
      </div>

      <button className="w-full mt-4 bg-blue-500 text-white font-bold py-3 rounded-lg hover:bg-blue-600 transition">
        Share
      </button>
    </div>
  );
};

export default CreatePost;
