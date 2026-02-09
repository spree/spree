# This migration comes from spree (originally 20250314144210)
class CreateSpreeTaggingsAndSpreeTags < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_taggings do |t|
      t.bigint "tag_id"
      t.string "taggable_type"
      t.bigint "taggable_id"
      t.string "tagger_type"
      t.bigint "tagger_id"
      t.string "context", limit: 128
      t.datetime "created_at", precision: nil
      t.string "tenant", limit: 128
      t.index ["context"], name: "index_spree_taggings_on_context"
      t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "spree_taggings_idx", unique: true
      t.index ["tag_id"], name: "index_spree_taggings_on_tag_id"
      t.index ["taggable_id", "taggable_type", "context"], name: "spree_taggings_taggable_context_idx"
      t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "spree_taggings_idy"
      t.index ["taggable_id"], name: "index_spree_taggings_on_taggable_id"
      t.index ["taggable_type", "taggable_id"], name: "index_spree_taggings_on_taggable_type_and_taggable_id"
      t.index ["taggable_type"], name: "index_spree_taggings_on_taggable_type"
      t.index ["tagger_id", "tagger_type"], name: "index_spree_taggings_on_tagger_id_and_tagger_type"
      t.index ["tagger_id"], name: "index_spree_taggings_on_tagger_id"
      t.index ["tagger_type", "tagger_id"], name: "index_spree_taggings_on_tagger_type_and_tagger_id"
      t.index ["tenant"], name: "index_spree_taggings_on_tenant"
    end

    create_table :spree_tags do |t|
      t.string "name"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "taggings_count", default: 0
      t.index ["name"], name: "index_spree_tags_on_name", unique: true
    end

    if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
      add_index :spree_tags, 'lower(name) varchar_pattern_ops', name: 'index_spree_tags_on_lower_name'
    end
  end
end
