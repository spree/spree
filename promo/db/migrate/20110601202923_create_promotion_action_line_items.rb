class CreatePromotionActionLineItems < ActiveRecord::Migration
  def change
    create_table :promotion_action_line_items do |t|
      t.integer :promotion_action_id, :variant_id
      t.integer :quantity, :default => 1
      t.references :promotion_action
      t.references :variant
    end
  end
end
