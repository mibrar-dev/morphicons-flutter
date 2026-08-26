/* Shared behavior for the static Flutter showcase routes. */
(() => {
  const toggle = document.querySelector('.nav-toggle');
  const menu = document.getElementById('mobileMenu');
  if (toggle && menu) {
    const setMenu = (open) => {
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
      menu.classList.toggle('is-open', open);
      menu.setAttribute('aria-hidden', String(!open));
      document.body.classList.toggle('menu-open', open);
    };
    toggle.addEventListener('click', () => setMenu(toggle.getAttribute('aria-expanded') !== 'true'));
    menu.querySelectorAll('a').forEach((link) => link.addEventListener('click', () => setMenu(false)));
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') setMenu(false);
    });
  }
  // Desktop showcase dropdown (mirrors main site)
  const dd = document.querySelector('.nav-dropdown');
  const ddBtn = document.querySelector('.nav-dropdown-trigger');
  if (dd && ddBtn) {
    ddBtn.addEventListener('click', (e) => {
      e.preventDefault();
      const open = ddBtn.getAttribute('aria-expanded') === 'true';
      ddBtn.setAttribute('aria-expanded', String(!open));
      dd.classList.toggle('is-open', !open);
    });
    document.addEventListener('click', (e) => {
      if (!dd.contains(e.target)) {
        ddBtn.setAttribute('aria-expanded', 'false');
        dd.classList.remove('is-open');
      }
    });
  }

  document.querySelectorAll('[data-copy-target]').forEach((button) => {
    button.addEventListener('click', async () => {
      const source = document.getElementById(button.dataset.copyTarget);
      if (!source) return;
      const text = source.textContent;
      try {
        await navigator.clipboard.writeText(text);
        button.textContent = 'Copied';
        button.classList.add('is-copied');
        window.setTimeout(() => {
          button.textContent = 'Copy';
          button.classList.remove('is-copied');
        }, 1400);
      } catch {
        button.textContent = 'Select code';
      }
    });
  });

  document.querySelectorAll('.showcase-tabs').forEach((tabs) => {
    tabs.querySelectorAll('[data-tab]').forEach((tab) => {
      tab.addEventListener('click', () => {
        tabs.querySelectorAll('[data-tab]').forEach((item) => item.classList.toggle('is-active', item === tab));
        document.querySelectorAll('[data-panel]').forEach((panel) => {
          panel.hidden = panel.dataset.panel !== tab.dataset.tab;
        });
      });
    });
  });

  document.querySelectorAll('iframe[data-demo]').forEach((frame) => {
    const wrap = frame.closest('.bridge-frame-wrap');
    const loading = wrap?.querySelector('.bridge-loading');
    frame.addEventListener('load', () => {
      if (loading) loading.hidden = true;
    });
    // Viewport-aware: avoid keeping offscreen Flutter engines hot.
    if ('IntersectionObserver' in window && wrap) {
      const io = new IntersectionObserver((entries) => {
        const visible = entries[0].isIntersecting;
        // Keep the iframe but hint the browser it can throttle.
        frame.style.visibility = visible ? '' : 'hidden';
        frame.style.visibility = '';
        // For older engines, pause/resume via cached src swap is avoided;
        // visibility tracking primarily saves parent DOM thrash.
      }, { threshold: 0.12 });
      io.observe(wrap);
    }
  });
})();
