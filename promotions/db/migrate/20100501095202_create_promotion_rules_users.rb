class CreatePromotionRulesUsers < ActiveRecord::Migration
  def self.up
    create_table :promotion_rules_users do |t|
      t.integer :user_id, :promotion_rule_id
    end
    remove_column :promotion_rules_users, :id
    add_index :promotion_rules_users, :user_id
    add_index :promotion_rules_users, :promotion_rule_id    
  end

  def self.down
    drop_table :promotion_rules_users
  end
end