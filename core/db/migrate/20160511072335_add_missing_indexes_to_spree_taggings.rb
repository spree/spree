class AddMissingIndexesToSpreeTaggings < ActiveRecord::Migration[4.2]
  def change
    add_index :spree_taggings, :tag_id
    add_index :spree_taggings, :taggable_id
    add_index :spree_taggings, :taggable_type
    add_index :spree_taggings, :tagger_id
    add_index :spree_taggings, :context

    add_index :spree_taggings, [:tagger_id, :tagger_type]
    add_index :spree_taggings,
              [:taggable_id, :taggable_type, :tagger_id, :context],
              name: "spree_taggings_idy"
  end
end
