class CreateSpreeTaxonsPromotionRules < ActiveRecord::Migration[4.2]
  def change
    create_table :spree_taxons_promotion_rules do |t|
      t.references :taxon, index: true
      t.references :promotion_rule, index: true
    end
  end
end
