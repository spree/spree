class CreateSpreeTaxExemptionCertificates < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_tax_exemption_certificates do |t|
      t.references :company, null: false
      t.references :country                  # nil = every country
      t.references :state                    # nil = the entire country
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
  end
end
