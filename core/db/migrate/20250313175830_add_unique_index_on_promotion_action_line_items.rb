class AddUniqueIndexOnPromotionActionLineItems < ActiveRecord::Migration[7.2]
  def change
    # Remove duplicate promotion action line items
    execute <<-SQL
      DELETE FROM spree_promotion_action_line_items
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM spree_promotion_action_line_items
        GROUP BY promotion_action_id, variant_id
      );
    SQL

    add_index :spree_promotion_action_line_items, [:promotion_action_id, :variant_id], unique: true
  end
end
