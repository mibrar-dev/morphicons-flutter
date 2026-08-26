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
    const loading = frame.closest('.bridge-frame-wrap')?.querySelector('.bridge-loading');
    frame.addEventListener('load', () => {
      if (loading) loading.hidden = true;
    });
  });
})();
