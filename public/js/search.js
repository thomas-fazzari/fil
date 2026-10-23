let timer;
let searching = false;
let caret = null;

const search = (form) => {
  clearTimeout(timer);
  if (!form.isConnected) {
    return;
  }
  const url = new URL(form.action);
  for (const [name, value] of new FormData(form)) {
    if (value) {
      url.searchParams.set(name, value);
    }
  }
  searching = true;
  Turbo.visit(url, { action: new URL(location).searchParams.has("q") ? "replace" : "advance" });
};

const isShortcut = (event) => {
  if (
    (event.metaKey || event.ctrlKey) &&
    !event.shiftKey &&
    !event.altKey &&
    event.key.toLowerCase() === "k"
  ) {
    return true;
  }
  return (
    event.key === "/" &&
    !event.metaKey &&
    !event.ctrlKey &&
    !event.altKey &&
    !event.target.closest("input, textarea, [contenteditable]")
  );
};

document.addEventListener("input", (event) => {
  if (!event.target.matches(".search__input")) {
    return;
  }
  clearTimeout(timer);
  timer = setTimeout(search, 300, event.target.form);
});

document.addEventListener("submit", (event) => {
  if (!event.target.matches(".search")) {
    return;
  }
  event.preventDefault();
  search(event.target);
});

document.addEventListener("keydown", (event) => {
  if (!isShortcut(event)) {
    return;
  }
  event.preventDefault();
  const input = document.querySelector(".search__input");
  input.focus();
  input.select();
});

document.addEventListener("turbo:click", () => {
  clearTimeout(timer);
});

// The new page replaces the field, so carry over what was typed while it loaded
document.addEventListener("turbo:before-render", (event) => {
  const input = document.activeElement;
  if (!searching || !input.matches(".search__input")) {
    return;
  }
  caret = input.selectionStart;
  event.detail.newBody.querySelector(".search__input").value = input.value;
});

document.addEventListener("turbo:render", () => {
  searching = false;
  if (caret === null) {
    return;
  }
  const input = document.querySelector(".search__input");
  input.focus();
  input.setSelectionRange(caret, caret);
  caret = null;
});

// Morphs would otherwise reset the field to the server value while it is being typed in
document.addEventListener("turbo:before-morph-attribute", (event) => {
  if (event.target === document.activeElement && event.detail.attributeName === "value") {
    event.preventDefault();
  }
});
