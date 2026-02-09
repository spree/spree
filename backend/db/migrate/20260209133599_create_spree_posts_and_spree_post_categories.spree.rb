# This migration comes from spree (originally 20250121160028)
class CreateSpreePostsAndSpreePostCategories < ActiveRecord::Migration[6.1]
  def change
    if !table_exists?(:spree_post_categories)
      create_table :spree_post_categories do |t|
        t.references :store, null: false, index: true
        t.string :title, null: false
        t.string :slug, null: false

        t.timestamps

        t.index ['slug', 'store_id'], name: 'index_spree_post_categories_on_slug_and_store_id', unique: true
      end
    end

    if !table_exists?(:spree_posts)
      create_table :spree_posts do |t|
        t.references :author, index: true
        t.datetime :published_at
        t.string :title, null: false
        t.string :slug, null: false
        t.references :post_category, index: true
        t.references :store, index: true
        t.string :meta_title
        t.string :meta_description

        t.timestamps
        t.datetime :deleted_at

        t.index ['title'], name: 'index_spree_posts_on_title'
      end
    end
  end
end
