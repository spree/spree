class AddMetadataToSpreeTaxRates < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_tax_rates do |t|
      if t.respond_to? :jsonb
        add_column :spree_tax_rates, :metadata, :jsonb
      else
        add_column :spree_tax_rates, :metadata, :json
      end
    end
  end
end
