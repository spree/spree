class RenameProductsPromotionRulesToSpreeProductsPromotionRules < ActiveRecord::Migration
  def up
    rename_table :products_promotion_rules, :spree_products_promotion_rules
  end

  def down
    raise IrreversibleMigration
  end
end
