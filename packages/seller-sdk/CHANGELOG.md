# @spree/seller-sdk

## 1.0.0-beta.3

### Minor Changes

- [#14736](https://github.com/spree/spree/pull/14736) [`e601826`](https://github.com/spree/spree/commit/e601826eb3cc701bc918ae7ddb9c2c52598e02d7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Invitation listings no longer include `acceptance_url`, because the link carries the token that accepts the invitation. Fetch it on demand with `invitations.acceptanceLink(id)` (and `sellers.invitations.acceptanceLink(sellerId, id)` in the Admin SDK), which needs write access. The "Copy invitation link" actions in the dashboard and the seller panel now use it.

## 1.0.0-beta.2

### Patch Changes

- Released alongside the dashboard packages it is versioned with.

## 1.0.0-beta.1

### Patch Changes

- [#14593](https://github.com/spree/spree/pull/14593) [`0f22450`](https://github.com/spree/spree/commit/0f224508b3d270aaa9899a508966a27c37f873ed) Thanks [@Hemang-ai](https://github.com/Hemang-ai)! - Preserve HTTP error statuses when a server returns an empty, non-JSON, or malformed error body. Avoid treating these responses as network failures, and allow admin and seller session recovery to handle unauthorized responses.
