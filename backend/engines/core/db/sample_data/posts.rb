store = Spree::Store.default

store.posts.where(title: 'Hello World').first_or_create!(
  content: 'This is a test post',
  published_at: Time.current,
  author: Spree.admin_user_class.first
)
