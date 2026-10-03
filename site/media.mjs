const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
const automaticVideos = [...document.querySelectorAll('video[autoplay]')];

function applyMotionPreference() {
  for (const video of automaticVideos) {
    if (motion.matches) {
      video.pause();
      video.removeAttribute('autoplay');
    } else {
      video.setAttribute('autoplay', '');
      video.play().catch(() => {});
    }
  }
}

applyMotionPreference();
motion.addEventListener('change', applyMotionPreference);
