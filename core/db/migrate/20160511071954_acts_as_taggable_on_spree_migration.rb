class ActsAsTaggableOnSpreeMigration < ActiveRecord::Migration[4.2]
  def self.up
    create_table :spree_tags do |t|
      t.string :name
      t.integer :taggings_count, default: 0
    end

    create_table :spree_taggings do |t|
      t.references :tag

      # You should make sure that the column created is
      # long enough to store the required class names.
      t.references :taggable, polymorphic: true
      t.references :tagger, polymorphic: true

      # Limit is created to prevent MySQL error on index
      # length for MyISAM table type: http://bit.ly/vgW2Ql
      t.string :context, limit: 128

      t.datetime :created_at
    end

    add_index :spree_tags, :name, unique: true
    add_index :spree_taggings,
              [
                :tag_id,
                :taggable_id,
                :taggable_type,
                :context,
                :tagger_id,
                :tagger_type
              ],
              unique: true, name: "spree_taggings_idx"
  end

  def self.down
    drop_table :spree_taggings
    drop_table :spree_tags
  end
end
