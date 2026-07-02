(function () {
  const root = document.querySelector("[data-carousel]");
  if (!root) return;

  const track = root.querySelector("[data-carousel-track]");
  const slides = Array.from(root.querySelectorAll("[data-carousel-slide]"));
  const dots = Array.from(root.querySelectorAll("[data-carousel-dot]"));
  const prev = root.querySelector("[data-carousel-prev]");
  const next = root.querySelector("[data-carousel-next]");
  let index = 0;
  let timer = null;

  function goTo(i) {
    index = (i + slides.length) % slides.length;
    track.style.transform = `translateX(-${index * 100}%)`;
    dots.forEach((dot, n) => {
      dot.classList.toggle("is-active", n === index);
      dot.setAttribute("aria-selected", n === index ? "true" : "false");
    });
    slides.forEach((slide, n) => {
      slide.setAttribute("aria-hidden", n === index ? "false" : "true");
    });
  }

  function restartAuto() {
    if (timer) clearInterval(timer);
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    timer = setInterval(() => goTo(index + 1), 5200);
  }

  dots.forEach((dot, n) => {
    dot.addEventListener("click", () => {
      goTo(n);
      restartAuto();
    });
  });

  prev?.addEventListener("click", () => {
    goTo(index - 1);
    restartAuto();
  });

  next?.addEventListener("click", () => {
    goTo(index + 1);
    restartAuto();
  });

  root.addEventListener("keydown", (e) => {
    if (e.key === "ArrowLeft") {
      goTo(index - 1);
      restartAuto();
    }
    if (e.key === "ArrowRight") {
      goTo(index + 1);
      restartAuto();
    }
  });

  let touchStartX = 0;
  root.addEventListener(
    "touchstart",
    (e) => {
      touchStartX = e.changedTouches[0].clientX;
    },
    { passive: true }
  );
  root.addEventListener(
    "touchend",
    (e) => {
      const delta = e.changedTouches[0].clientX - touchStartX;
      if (Math.abs(delta) < 40) return;
      goTo(delta < 0 ? index + 1 : index - 1);
      restartAuto();
    },
    { passive: true }
  );

  goTo(0);
  restartAuto();
})();
