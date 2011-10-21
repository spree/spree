class CreatePromotionActionLineItems < ActiveRecord::Migration
  def self.up
    create_table :promotion_action_line_items do |t|
      t.integer :quantity, :default => 1
      t.references :promotion_action
      t.references :variant
    end
  end

  def self.down
    drop_table :promotion_action_line_items
  end
end
