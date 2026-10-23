const key = "fil:open-categories";

const openCategories = () => new Set(JSON.parse(localStorage.getItem(key)) ?? []);

const remember = (group) => {
  const open = openCategories();
  if (group.open) {
    open.add(group.dataset.category);
  } else {
    open.delete(group.dataset.category);
  }
  localStorage.setItem(key, JSON.stringify([...open]));
};

const restore = (root) => {
  const open = openCategories();
  for (const group of root.querySelectorAll(".tree__group")) {
    if (open.has(group.dataset.category)) {
      group.open = true;
    }
  }
};

document.addEventListener(
  "toggle",
  (event) => {
    const group = event.target;
    if (!group.matches(".tree__group")) {
      return;
    }
    if (group.open && group.querySelector("[aria-current]")) {
      return;
    }
    remember(group);
  },
  true,
);

restore(document);

document.addEventListener("turbo:before-render", (event) => {
  restore(event.detail.newBody);
});
