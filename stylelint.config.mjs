/** @type {import("stylelint").Config} */
export default {
  extends: ["stylelint-config-standard"],
  defaultSeverity: "error",
  ignoreFiles: ["**/local/**", "**/node_modules/**"],
  reportDescriptionlessDisables: true,
  reportInvalidScopeDisables: true,
  reportNeedlessDisables: true,
  reportUnscopedDisables: true,
  rules: {
    "custom-property-empty-line-before": null,
    "declaration-no-important": true,
    "hue-degree-notation": "number",
    "lightness-notation": "number",
    "max-nesting-depth": 2,
    "media-feature-range-notation": "context",
    "no-descending-specificity": null,
    "property-layout-mappings": "flow-relative",
    "property-no-vendor-prefix": true,
    "selector-class-pattern":
      "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?:__(?:[a-z0-9]+-?)+)?(?:--(?:[a-z0-9]+-?)+)?$",
    "selector-max-attribute": 2,
    "selector-max-compound-selectors": 5,
    "selector-max-id": 1,
    "selector-max-pseudo-class": 3,
    "selector-max-specificity": "1,4,1",
    "selector-max-type": 2,
    "selector-max-universal": 1,
    "selector-no-vendor-prefix": true,
    "unit-layout-mappings": "flow-relative",
    "value-keyword-case": ["lower", { ignoreKeywords: ["currentColor"] }],
    "value-keyword-layout-mappings": "flow-relative",
    "value-no-vendor-prefix": true,
  },
  overrides: [
    {
      files: ["public/css/reset.css", "public/css/document.css", "public/css/reader.css"],
      rules: {
        // Raw colors live only in tokens.css
        "color-no-hex": true,
        "function-disallowed-list": ["/^(?:color|hsl|hsla|hwb|lab|lch|oklab|oklch|rgb|rgba)$/"],
      },
    },
  ],
};
