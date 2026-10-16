class CreateSpreeTaxExemptionReasons < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_tax_exemption_reasons do |t|
      t.references :store, null: false, index: false
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :active, null: false, default: true
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_tax_exemption_reasons, [:store_id, :name], unique: true,
              name: 'idx_tax_exemption_reasons_on_store_and_name'
    add_index :spree_tax_exemption_reasons, [:store_id, :code], unique: true,
              name: 'idx_tax_exemption_reasons_on_store_and_code'
  end
end
