store = Spree::Store.default

store.posts.create!(
  title: 'Hello World',
  content: 'This is a test post',
  published_at: Time.current,
  author: store.admin_users.first,
)
