# spree_meilisearch

Instant product search, filtering and faceted navigation for Spree via [Meilisearch](https://www.meilisearch.com) — an implementation of the `Spree::SearchProvider` interface.

## What it does

- **`SpreeMeilisearch::SearchProvider`** answers product search, filtering and faceted navigation from a Meilisearch index instead of the database. One index per store. Search results are always intersected with the caller's ActiveRecord scope, so a stale index can never widen what a customer is allowed to see — it can only ever show less.
- **`SpreeMeilisearch::ProductPresenter`** builds the documents. Each product is indexed once per locale and currency it is priced in, with the fields flattened for filtering: price, stock, categories, collections, option values, tags, and any custom fields marked searchable or sortable.
- Facet counts are disjunctive: the counts shown for one option type are computed as if that type's own filters were not applied, so a customer picking "Red" still sees how many blue items are available.
- Merchant-ordered category and collection pages are supported through extra membership documents carrying the hand-set position.

Without this gem Spree searches the database directly (`Spree::SearchProvider::Database`), which needs no extra infrastructure but has no full-text ranking or typo tolerance.

## Setup

1. Run Meilisearch, and point the application at it:

   ```bash
   MEILISEARCH_URL=http://localhost:7700
   MEILISEARCH_API_KEY=your-master-key   # optional for a local server
   ```

   These are environment variables rather than dashboard settings because the index is infrastructure — one server serves every store in the installation, and the reindex task has to reach it outside a request.

2. Add the gem: `bundle add spree_meilisearch`

3. Select the provider in `config/initializers/spree.rb`:

   ```ruby
   Spree.search_provider = 'SpreeMeilisearch::SearchProvider'
   ```

4. Build the index: `bin/rails spree:search:reindex`

From then on, product changes are indexed in the background as they happen. Re-run the reindex task after adding a custom field that should be searchable, sortable or filterable.

## Upgrading from Spree 5.x

The provider used to live in `spree_core` as `Spree::SearchProvider::Meilisearch`. Add this gem and update the class name in your initializer:

```ruby
# before
Spree.search_provider = 'Spree::SearchProvider::Meilisearch'
# after
Spree.search_provider = 'SpreeMeilisearch::SearchProvider'
```

The old names still resolve with a deprecation warning for one release. Applications that subclassed `Spree::SearchProvider::ProductPresenter` should inherit from `SpreeMeilisearch::ProductPresenter` instead. No reindex is needed — the documents are unchanged.

## Testing

```bash
cd spree/providers/meilisearch
bundle install
bundle exec rake test_app
bundle exec rspec
```

The unit specs stub the Meilisearch client and run offline. The integration spec in `spec/requests/` exercises a real server and is skipped unless `MEILISEARCH_URL` is set — locally, `brew install meilisearch && meilisearch`; in CI it runs as a service container.
