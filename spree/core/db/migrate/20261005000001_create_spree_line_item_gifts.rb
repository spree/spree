class CreateSpreeLineItemGifts < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_line_item_gifts do |t|
      t.references :line_item, null: false, index: false
      t.references :promotion_action, null: false
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    add_index :spree_line_item_gifts, [:line_item_id, :promotion_action_id], unique: true,
              name: 'index_spree_line_item_gifts_on_line_item_and_promotion_action'
  end
end
