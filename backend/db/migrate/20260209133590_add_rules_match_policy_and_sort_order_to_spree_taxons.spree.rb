# This migration comes from spree (originally 20241127223627)
class AddRulesMatchPolicyAndSortOrderToSpreeTaxons < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_taxons, :rules_match_policy, :string, default: 'all', null: false
    add_column :spree_taxons, :sort_order, :string, default: 'manual', null: false
  end
end
