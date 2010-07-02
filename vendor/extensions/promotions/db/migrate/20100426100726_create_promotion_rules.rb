class CreatePromotionRules < ActiveRecord::Migration
  def self.up
    create_table :promotion_rules do |t|
      t.references :promotion, :user, :product_group
      t.timestamps
      t.string :type      
    end
    add_index :promotion_rules, :product_group_id
    add_index :promotion_rules, :user_id
    
    create_table :products_promotion_rules do |t|
      t.integer :product_id, :promotion_rule_id
    end
    remove_column :products_promotion_rules, :id
    add_index :products_promotion_rules, :product_id
    add_index :products_promotion_rules, :promotion_rule_id

  end

  def self.down
    drop_table :promotion_rules
    drop_table :products_promotion_rules
  end
end
