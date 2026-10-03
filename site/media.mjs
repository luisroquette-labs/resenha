const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
const automaticVideos = [...document.querySelectorAll('video[autoplay]')];
const revealTargets = [...document.querySelectorAll('[data-reveal]')];
let revealObserver;

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

  revealObserver?.disconnect();
  document.documentElement.classList.toggle('motion-ready', !motion.matches);
  if (motion.matches || !('IntersectionObserver' in window)) {
    for (const target of revealTargets) target.classList.add('is-revealed');
    return;
  }

  revealObserver = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('is-revealed');
      revealObserver.unobserve(entry.target);
    }
  }, { rootMargin: '0px 0px -8% 0px', threshold: .08 });
  for (const target of revealTargets) revealObserver.observe(target);
}

applyMotionPreference();
motion.addEventListener('change', applyMotionPreference);
