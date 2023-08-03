# settings for default store
Spree::DataFeed::Google.create!(
  store: Spree::Store.default,
  name: 'Default Google Data Feed'
)

