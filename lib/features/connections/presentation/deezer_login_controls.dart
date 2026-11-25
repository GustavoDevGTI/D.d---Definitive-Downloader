/// Restricts the official Deezer page to the email/password flow supported by
/// the app. No form values, cookies or credentials are read by this script.
const deezerLoginControlInstaller = r'''
() => {
  if (window.__ddEmailLoginOnly) return;
  window.__ddEmailLoginOnly = true;
  const selector = 'button,a,[role="button"],input[type="button"],input[type="submit"]';
  const providers = /google|facebook|apple|amazon|microsoft|twitter|\bx\s*login\b/i;
  function social(element) {
    if (!element || !element.matches(selector)) return false;
    const labels = ['aria-label','title','href','data-testid','data-test-id','id'];
    const text = [element.textContent || '', ...labels.map(key => element.getAttribute(key) || ''),
      ...Array.from(element.querySelectorAll('img[alt],svg[aria-label],use[href]'),
        icon => icon.getAttribute('alt') || icon.getAttribute('aria-label') || icon.getAttribute('href') || '')].join(' ');
    return providers.test(text);
  }
  function disable(element) {
    if (!social(element)) return;
    if ('disabled' in element && !element.disabled) element.disabled = true;
    if (element.getAttribute('aria-disabled') !== 'true') element.setAttribute('aria-disabled','true');
    if (element.tabIndex !== -1) element.tabIndex = -1;
    element.style.setProperty('pointer-events','none','important');
    element.style.setProperty('opacity','0.4','important');
    element.style.setProperty('cursor','not-allowed','important');
  }
  function scan(root) {
    if (!(root instanceof Element) && root !== document) return;
    if (root instanceof Element) disable(root);
    root.querySelectorAll(selector).forEach(disable);
  }
  for (const type of ['click','auxclick','pointerdown','keydown']) {
    window.addEventListener(type, event => {
      if (type === 'keydown' && !['Enter',' '].includes(event.key)) return;
      const element = event.target instanceof Element ? event.target.closest(selector) : null;
      if (social(element)) {
        event.preventDefault();
        event.stopImmediatePropagation();
      }
    }, true);
  }
  new MutationObserver(records => {
    for (const record of records) {
      if (record.type === 'attributes') disable(record.target);
      else record.addedNodes.forEach(scan);
    }
  }).observe(document, {childList:true,subtree:true,attributes:true,
    attributeFilter:['aria-label','title','href','data-testid','data-test-id','id','disabled','tabindex']});
  scan(document);
}
''';

const deezerLoginControls = r'''
(() => {
  if (location.protocol !== 'https:' ||
      !(location.hostname === 'deezer.com' || location.hostname.endsWith('.deezer.com'))) return;
  (''' +
    deezerLoginControlInstaller +
    r''')();
})();
''';
