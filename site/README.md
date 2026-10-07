# Montage site

`public/` is a static, product-native Montage landing page. It does not provide
Ress short links, profile storage, accounts, or any application API.

## Layout

```text
site/public/index.html   current landing page
site/public/_redirects   repository shortcut only
site/worker.js           optional static asset worker
site/archive/            predecessor site assets retained as historical material
```

Deploy to a static host only after assigning the final Montage domain and
updating canonical/Open Graph URLs. Until then, the page deliberately omits a
canonical domain and uses no active social image.

Release screenshots and social art must use the names in
`docs/release/marketplace.md`, show current Montage branding, and be captured
from the validated release commit. Predecessor assets remain under
`site/archive/ress-assets/` and must not be deployed.
