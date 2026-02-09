# This migration comes from spree (originally 20220120092821)
class AddMetadataToSpreeTaxRates < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_tax_rates do |t|
      if t.respond_to? :jsonb
        add_column :spree_tax_rates, :public_metadata, :jsonb
        add_column :spree_tax_rates, :private_metadata, :jsonb
      else
        add_column :spree_tax_rates, :public_metadata, :json
        add_column :spree_tax_rates, :private_metadata, :json
      end
    end
  end
end
