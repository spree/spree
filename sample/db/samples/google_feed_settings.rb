# settings for default store
Spree::GoogleFeedSetting.create!(
  store: Spree::Store.default,
  brand: true,
  material: true
)

