import React from 'react';

const Ads = () => {
  return (
    <div className="flex flex-col items-center justify-center min-h-[50vh] p-4">
      <div className="text-center">
        <h1 className="text-3xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange">
          Ads Center
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mb-8 max-w-md">
          Create and manage your ad campaigns here. Reach more people and grow your audience.
        </p>
        <button className="bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white px-6 py-3 rounded-full font-semibold shadow-md hover:shadow-lg transition-shadow">
          Create Ad
        </button>
      </div>
    </div>
  );
};

export default Ads;
