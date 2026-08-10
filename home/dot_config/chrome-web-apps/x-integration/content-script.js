(() => {
  "use strict";

  const integration = globalThis.xPwaIntegration;
  let mediaActive = false;

  const reconcileTitle = () => {
    const marker = integration.mediaTitleMarker;
    const unmarkedTitle = document.title.startsWith(marker)
      ? document.title.slice(marker.length)
      : document.title;
    const expectedTitle = mediaActive ? marker + unmarkedTitle : unmarkedTitle;
    if (document.title !== expectedTitle) document.title = expectedTitle;
  };

  const reconcileUrl = (value = location.href) => {
    mediaActive = integration.isMediaUrl(value);
    reconcileTitle();
  };

  const titleObserver = new MutationObserver(reconcileTitle);
  titleObserver.observe(document.head, {
    childList: true,
    characterData: true,
    subtree: true,
  });

  chrome.runtime.onMessage.addListener((message) => {
    if (message?.type === "x-url-changed" && typeof message.url === "string") {
      reconcileUrl(message.url);
    }
  });

  const routeExternalLink = (event) => {
    if (event.defaultPrevented) return;
    if (event.type === "click" && event.button !== 0) return;
    if (event.type === "auxclick" && event.button !== 1) return;

    const anchor = event.target instanceof Element ? event.target.closest("a[href]") : null;
    if (!anchor || anchor.hasAttribute("download")) return;

    let url;
    try {
      url = new URL(anchor.href, location.href);
    } catch {
      return;
    }
    if (url.protocol !== "http:" && url.protocol !== "https:") return;
    if (integration.isInternalUrl(url.href)) return;

    event.preventDefault();
    event.stopImmediatePropagation();
    location.assign(integration.encodeExternalUrl(url.href));
  };

  document.addEventListener("click", routeExternalLink, true);
  document.addEventListener("auxclick", routeExternalLink, true);
  reconcileUrl();
})();
