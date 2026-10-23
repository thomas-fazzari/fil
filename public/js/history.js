document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-history]");
  if (!button) {
    return;
  }
  const site = window.navigation;
  if (button.dataset.history === "back") {
    if (!site || site.canGoBack) {
      history.back();
    }
  } else if (!site || site.canGoForward) {
    history.forward();
  }
});

let restored = false;

document.addEventListener("turbo:visit", (event) => {
  restored = event.detail.action === "restore";
});

document.addEventListener("turbo:load", (event) => {
  const stale = restored && !event.detail.timing.requestStart;
  restored = false;
  if (!stale) {
    return;
  }
  // Same restoration id keeps the saved scroll, and Turbo forgets a visit started inside turbo:load
  const restorationIdentifier = Turbo.session.restorationIdentifier;
  setTimeout(() => {
    Turbo.visit(location.href, { action: "replace", restorationIdentifier });
  });
});
