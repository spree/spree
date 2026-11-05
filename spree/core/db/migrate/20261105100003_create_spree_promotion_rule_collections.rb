class CreateSpreePromotionRuleCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_promotion_rule_collections do |t|
      t.references :promotion_rule, null: false
      t.references :collection, null: false
      t.timestamps
    end

    add_index :spree_promotion_rule_collections, %i[promotion_rule_id collection_id], unique: true,
                                                                                      name: 'index_promotion_rule_collections_on_rule_and_collection'
  end
end
