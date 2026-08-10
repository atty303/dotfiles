"use strict";

const notifyUrlChange = (details) => {
  if (details.frameId !== 0 || !details.url) return;
  chrome.tabs.sendMessage(details.tabId, {
    type: "x-url-changed",
    url: details.url,
  }).catch(() => {});
};

const filter = { url: [{ hostSuffix: "x.com", schemes: ["https"] }] };
chrome.webNavigation.onCommitted.addListener(notifyUrlChange, filter);
chrome.webNavigation.onHistoryStateUpdated.addListener(notifyUrlChange, filter);
chrome.webNavigation.onReferenceFragmentUpdated.addListener(notifyUrlChange, filter);
