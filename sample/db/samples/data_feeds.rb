# settings for default store
Spree::DataFeed.create!(
  store: Spree::Store.default,
  name: 'Default Google Data Feed',
  provider: 'google'
)

