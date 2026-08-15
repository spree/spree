class CreateSpreeTaxExemptionCertificates < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_tax_exemption_certificates do |t|
      t.references :company, null: false
      # Codes, not references: Country and State are being dropped, and a blank
      # code is what "everywhere" means here. Same shape as spree_tax_rates.
      t.string :country_code                  # nil = every country
      t.string :state_code                   # nil = the entire country
      t.string :certificate_number, null: false
      t.string :reason_code, null: false     # resale, government, … — becomes the
                                             # provider's entity use code
      t.string :status, null: false          # no DB default: set by the creating service
      t.datetime :issued_at
      t.datetime :expires_at
      t.string :issuing_authority
      # Who accepted the certificate, and when — the same pair every other
      # reviewed record keeps.
      t.datetime :verified_at
      t.references :verified_by
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_tax_exemption_certificates, [:company_id, :status]
    add_index :spree_tax_exemption_certificates, [:country_code, :state_code]
  end
end
