# This migration comes from spree (originally 20241127193411)
class CreateSpreeTaxonRules < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_taxon_rules do |t|
      t.belongs_to :taxon, null: false, index: true

      t.string :type, null: false
      t.string :value, null: false
      t.string :match_policy, null: false, default: 'is_equal_to'

      t.timestamps
    end
  end
end
