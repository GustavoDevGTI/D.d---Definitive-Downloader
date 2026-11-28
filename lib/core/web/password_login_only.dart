import 'dart:convert';

/// Restricts an official login page to the username/password flow supported
/// by the app: buttons, links and embedded frames of other sign-in providers
/// are disabled in the page itself. No form values, cookies or credentials are
/// read. Called without a pattern, it blocks every provider in
/// [signInProviders].
const socialSignInBlocker = r'''
(blocked) => {
  if (window.__ddEmailLoginOnly) return;
  window.__ddEmailLoginOnly = true;
  const selector = 'button,a,[role="button"],input[type="button"],input[type="submit"],iframe';
  const providers = blocked instanceof RegExp ? blocked
    : /google|facebook|apple|amazon|microsoft|twitter|\bx\s*login\b|instagram|kakao|\bline\b/i;
  function social(element) {
    if (!element || !element.matches(selector)) return false;
    const labels = ['aria-label','title','href','src','data-testid','data-test-id','id'];
    const text = [element.tagName === 'IFRAME' ? '' : element.textContent || '',
      ...labels.map(key => element.getAttribute(key) || ''),
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
    attributeFilter:['aria-label','title','href','src','data-testid','data-test-id','id','disabled','tabindex']});
  scan(document);
}
''';

/// Other companies' sign-in options, as regular expression fragments.
const signInProviders = [
  'google',
  'facebook',
  'apple',
  'amazon',
  'microsoft',
  'twitter',
  r'\bx\s*login\b',
  'instagram',
  'kakao',
  r'\bline\b',
];

/// Runs [socialSignInBlocker] only on HTTPS pages of [domains] or their
/// subdomains. [ownBrands] stay enabled: a platform's own buttons and links
/// are not another company's sign-in. Values come from the app's constants.
String passwordLoginOnly(List<String> domains,
    {List<String> ownBrands = const []}) {
  assert(domains.isNotEmpty &&
      domains.every((d) => RegExp(r'^[a-z0-9.-]+$').hasMatch(d)));
  final hosts = jsonEncode(domains);
  final blocked = signInProviders
      .where((provider) => !ownBrands.any((brand) =>
          provider == brand || (brand == 'x' && provider.contains(r'\bx'))))
      .join('|');
  return """
(() => {
  const hosts = $hosts;
  if (location.protocol !== 'https:' ||
      !hosts.some(h => location.hostname === h || location.hostname.endsWith('.' + h))) return;
  ($socialSignInBlocker)(new RegExp(${jsonEncode(blocked)}, 'i'));
})();
""";
}
