document.addEventListener("submit", (event) => {
  if (!event.target.matches("[data-theme-toggle]")) {
    return;
  }
  event.preventDefault();
  const theme = document.documentElement.dataset.theme === "light" ? "dark" : "light";
  document.documentElement.dataset.theme = theme;
  document.cookie = `fil_theme=${theme}; path=/; max-age=315360000`;
});
