// Resize existing floating panels without changing their map anchors.
for (const panel of document.querySelectorAll('[data-resize]')) {
  const northEast = panel.dataset.resize === 'ne';
  const handle = document.createElement('button');
  const name = panel.querySelector('h2').textContent.replace(/\s+\d+\s*$/, '').trim();
  handle.type = 'button';
  handle.className = 'panel-resize';
  handle.setAttribute('aria-label', `Resize ${name}`);
  handle.setAttribute('aria-description', 'Drag or use arrow keys. Hold Shift for larger steps. Press Home or double-click to reset.');
  handle.title = 'Drag to resize · Arrow keys · Home or double-click to reset';
  handle.innerHTML = '<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 18 12-12M6 12l6-6"/></svg>';
  panel.classList.add('resizable-panel');
  panel.append(handle);
  let drag = null;

  function setSize(width, height, rect = panel.getBoundingClientRect()) {
    const top = document.querySelector('.toolbar').getBoundingClientRect().bottom + 12;
    const maxWidth = Math.max(1, Math.min(640, northEast ? innerWidth - rect.left - 12 : rect.right - 12));
    const maxHeight = Math.max(1, Math.min(
      parseFloat(getComputedStyle(panel).maxHeight) || Infinity,
      northEast ? rect.bottom - top : innerHeight - rect.top - 24,
    ));
    panel.style.width = `${Math.max(Math.min(northEast ? 200 : 240, maxWidth), Math.min(maxWidth, width))}px`;
    panel.style.height = `${Math.max(Math.min(160, maxHeight), Math.min(maxHeight, height))}px`;
    panel.dataset.sized = '';
  }
  function reset() {
    panel.style.removeProperty('width');
    panel.style.removeProperty('height');
    delete panel.dataset.sized;
  }
  handle.addEventListener('pointerdown', event => {
    if (event.button !== 0 || !event.isPrimary || drag) return;
    event.preventDefault();
    event.stopPropagation();
    handle.focus({preventScroll: true});
    drag = {pointerId: event.pointerId, x: event.clientX, y: event.clientY, rect: panel.getBoundingClientRect()};
    panel.dataset.resizing = '';
    handle.setPointerCapture(event.pointerId);
  });
  window.addEventListener('pointermove', event => {
    if (!drag || event.pointerId !== drag.pointerId) return;
    setSize(drag.rect.width + (event.clientX - drag.x) * (northEast ? 1 : -1),
      drag.rect.height + (event.clientY - drag.y) * (northEast ? -1 : 1), drag.rect);
  });
  const stop = event => {
    if (drag && event.pointerId !== undefined && event.pointerId !== drag.pointerId) return;
    drag = null;
    delete panel.dataset.resizing;
  };
  window.addEventListener('pointerup', stop);
  window.addEventListener('pointercancel', stop);
  window.addEventListener('blur', stop);
  handle.addEventListener('dblclick', reset);
  handle.addEventListener('keydown', event => {
    if (event.key === 'Home') {event.preventDefault(); reset(); return;}
    const movement = {ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1]}[event.key];
    if (!movement) return;
    event.preventDefault();
    const rect = panel.getBoundingClientRect(), step = event.shiftKey ? 40 : 16;
    setSize(rect.width + movement[0] * step * (northEast ? 1 : -1),
      rect.height + movement[1] * step * (northEast ? -1 : 1));
  });
  window.addEventListener('resize', () => {
    if (!panel.hasAttribute('data-sized') || !panel.getClientRects().length) return;
    // A collapsed module keeps its expanded height for the next opening.
    if (panel.querySelector(':scope > .panel-heading [aria-expanded="false"]')) return;
    const rect = panel.getBoundingClientRect();
    setSize(rect.width, rect.height);
  });
}
