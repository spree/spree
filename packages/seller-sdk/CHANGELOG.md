# @spree/seller-sdk

## 0.1.1

### Patch Changes

- [#14593](https://github.com/spree/spree/pull/14593) [`0f22450`](https://github.com/spree/spree/commit/0f224508b3d270aaa9899a508966a27c37f873ed) Thanks [@Hemang-ai](https://github.com/Hemang-ai)! - Preserve HTTP error statuses when a server returns an empty, non-JSON, or malformed error body. Avoid treating these responses as network failures, and allow admin and seller session recovery to handle unauthorized responses.
