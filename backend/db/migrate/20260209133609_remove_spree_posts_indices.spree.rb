# This migration comes from spree (originally 20250305121657)
class RemoveSpreePostsIndices < ActiveRecord::Migration[7.2]
  def change
    if index_name_exists?(:spree_posts, 'index_spree_posts_on_slug_and_store_id')
      remove_index :spree_posts, name: 'index_spree_posts_on_slug_and_store_id'
    end
  end
end
