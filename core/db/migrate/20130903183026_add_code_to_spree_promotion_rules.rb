class AddCodeToSpreePromotionRules < ActiveRecord::Migration
  def change
    add_column :spree_promotion_rules, :code, :string
  end
end
