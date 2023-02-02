# settings for default store
Spree::DataFeedSetting.create!(
  store: Spree::Store.default,
  name: 'Default Google Data Feed',
  provider: 'google'
)

