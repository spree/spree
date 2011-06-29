class PromotionChangesToSubclassOfActivator < ActiveRecord::Migration
  def self.up
    drop_table :promotions
    rename_column :promotion_rules, :promotion_id, :activator_id
  end

  def self.down
    create_table "promotions", :force => true do |t|
      t.string   "name"
      t.string   "code"
      t.string   "description"
      t.integer  "usage_limit"
      t.boolean  "combine"
      t.datetime "expires_at"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.datetime "starts_at"
      t.string   "match_policy", :default => "all"
    end
    rename_column :promotion_rules, :activator_id, :promotion_id
  end
end
