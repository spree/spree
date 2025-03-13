class AddUniqueIndexOnPromotionRulesAssociations < ActiveRecord::Migration[7.2]
  def change
    # Remove duplicate product promotion rules
    execute <<-SQL
      DELETE FROM spree_product_promotion_rules
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM spree_product_promotion_rules
        GROUP BY product_id, promotion_rule_id
      );
    SQL

    # Remove duplicate taxon promotion rules
    execute <<-SQL
      DELETE FROM spree_promotion_rule_taxons
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM spree_promotion_rule_taxons
        GROUP BY taxon_id, promotion_rule_id
      );
    SQL

    # Remove duplicate user promotion rules
    execute <<-SQL
      DELETE FROM spree_promotion_rule_users
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM spree_promotion_rule_users
        GROUP BY user_id, promotion_rule_id
      );
    SQL

    add_index :spree_product_promotion_rules, [:product_id, :promotion_rule_id], unique: true
    add_index :spree_promotion_rule_taxons, [:taxon_id, :promotion_rule_id], unique: true
    add_index :spree_promotion_rule_users, [:user_id, :promotion_rule_id], unique: true
  end
end
