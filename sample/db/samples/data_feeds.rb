# settings for default store
Spree::DataFeed::Google.create!(
  store: Spree::Store.default,
  name: 'Канал даних Google за умовчанням'
)
