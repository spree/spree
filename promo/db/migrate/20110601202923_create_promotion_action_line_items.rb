class CreatePromotionActionLineItems < ActiveRecord::Migration
  def self.up
    create_table "promotion_action_line_items" do |t|
      t.integer :promotion_action_id, :variant_id
      t.integer :quantity, :default => 1
    end
  end

  def self.down
    drop_table "promotion_action_line_items"
  end
end
