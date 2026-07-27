# @spree/dashboard

## 0.13.0

### Minor Changes

- [#14342](https://github.com/spree/spree/pull/14342) [`202d846`](https://github.com/spree/spree/commit/202d846374270c75e19b23cea5498ea559577f67) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Add per-channel order routing rule management. `@spree/admin-sdk` gains `channels.orderRoutingRules.{list,get,create,update,delete}` (nested under `/channels/:channel_id/order_routing_rules`) plus `orderRoutingRules.types()` for rule-kind discovery; the admin `Store` type now exposes `preferred_order_routing_strategy`. The dashboard's channel edit sheet embeds a routing-rules editor — drag-to-reorder priority, per-rule active toggles, an "Add rule" picker fed by the types endpoint (offering only kinds not yet on the channel; rule kinds are unique per channel), and schema-driven preference forms for rule kinds that declare preferences. The editor renders only when the channel's effective routing strategy is Rules. `Subject.OrderRoutingRule` is available for permission checks.

- [#14341](https://github.com/spree/spree/pull/14341) [`dc33237`](https://github.com/spree/spree/commit/dc332372b918ffeb92252c33372a1d71a221a7d4) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Improve editing of quantity-bounded price rules. A blank upper-bound preference (`max_quantity`, `max_uses`, `maximum_amount`, …) now shows "Unlimited" instead of an empty required-looking field across every preferences form. The Volume price rule gains a dedicated editor that renders minimum quantity before maximum, so a case-pack minimum reads in a natural order.

### Patch Changes

- Updated dependencies [[`202d846`](https://github.com/spree/spree/commit/202d846374270c75e19b23cea5498ea559577f67), [`dc33237`](https://github.com/spree/spree/commit/dc332372b918ffeb92252c33372a1d71a221a7d4)]:
  - @spree/admin-sdk@0.8.0
  - @spree/dashboard-core@0.13.0
  - @spree/dashboard-ui@0.13.0

## 0.12.0

### Minor Changes

- [#14339](https://github.com/spree/spree/pull/14339) [`b71e613`](https://github.com/spree/spree/commit/b71e61326289d7ef4038a4bd55f353569a242d52) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Re-export the plugin facade (`defineDashboardPlugin` and its types) from `@spree/dashboard`, so host apps can register in-app customizations without declaring `@spree/dashboard-core` as a direct dependency. Distributed plugins keep importing from `@spree/dashboard-core/plugin`.

### Patch Changes

- Updated dependencies []:
  - @spree/dashboard-core@0.12.0
  - @spree/dashboard-ui@0.12.0

## 0.11.0

### Minor Changes

- Manage channel binding for publishable API keys. The create dialog offers an optional channel select (defaulting to all channels) when the key type is publishable, and the publishable keys table gains a Channel column showing each key's bound channel or "All channels".

## 0.10.3

### Patch Changes

- Refresh resource lists when a CSV import finishes. Imports create records server-side outside any tracked mutation, and the list under the import wizard stays mounted — so it kept serving the pre-import cache. The import's target resources (plus option types and categories for product imports) and the imports history are now invalidated whenever the poll observes the run finishing, including failed and retried runs.

## 0.10.2

### Patch Changes

- Fix the product edit form collapsing multi-paragraph descriptions on reload. The description editor now hydrates from the API's `description_html` field instead of the tag-stripped plain-text `description`, so paragraphs, line breaks, and inline formatting survive save and reload cycles.
