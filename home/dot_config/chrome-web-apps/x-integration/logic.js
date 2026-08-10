(() => {
  "use strict";

  const mediaTitleMarker = "⟦X media⟧ ";
  const internalHostPattern = /(^|\.)(x\.com|twitter\.com)$/i;
  const mediaPathPattern = /\/status\/\d+\/(?:photo|video)\/\d+(?:\/|$)/;

  const isInternalUrl = (value) => {
    try {
      const url = new URL(value);
      return (url.protocol === "http:" || url.protocol === "https:") &&
        internalHostPattern.test(url.hostname);
    } catch {
      return false;
    }
  };

  const isMediaUrl = (value) => {
    try {
      const url = new URL(value);
      return url.protocol === "https:" &&
        /(^|\.)x\.com$/i.test(url.hostname) &&
        mediaPathPattern.test(url.pathname);
    } catch {
      return false;
    }
  };

  const encodeExternalUrl = (value) => {
    const bytes = new TextEncoder().encode(value);
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return `x-open-default:${btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "")}`;
  };

  globalThis.xPwaIntegration = Object.freeze({
    encodeExternalUrl,
    isInternalUrl,
    isMediaUrl,
    mediaTitleMarker,
  });
})();
