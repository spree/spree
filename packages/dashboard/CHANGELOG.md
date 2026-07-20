# @spree/dashboard

## 0.11.0

### Minor Changes

- Manage channel binding for publishable API keys. The create dialog offers an optional channel select (defaulting to all channels) when the key type is publishable, and the publishable keys table gains a Channel column showing each key's bound channel or "All channels".

## 0.10.3

### Patch Changes

- Refresh resource lists when a CSV import finishes. Imports create records server-side outside any tracked mutation, and the list under the import wizard stays mounted — so it kept serving the pre-import cache. The import's target resources (plus option types and categories for product imports) and the imports history are now invalidated whenever the poll observes the run finishing, including failed and retried runs.

## 0.10.2

### Patch Changes

- Fix the product edit form collapsing multi-paragraph descriptions on reload. The description editor now hydrates from the API's `description_html` field instead of the tag-stripped plain-text `description`, so paragraphs, line breaks, and inline formatting survive save and reload cycles.
