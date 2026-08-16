class CreateSpreeVendors < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_vendors do |t|
      t.references :store, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, null: false # no DB default: set by the creating workflow
      t.string :contact_email
      t.string :billing_email
      t.text :about
      t.references :billing_address
      t.references :returns_address

      # Vendor acceptance of the store's seller terms — the timestamp is the
      # record of it, so onboarding can ask again when the terms change.
      t.datetime :terms_accepted_at
      # Set while the vendor is away: their catalog stays but stops selling.
      t.datetime :holiday_mode_until

      # Settlement configuration. Both nil mean "use the store's default", so
      # a vendor only carries a value once it deviates.
      t.string :payouts_schedule_interval
      t.decimal :minimum_payout_amount, precision: 10, scale: 2

      # Who remits consumer tax on this vendor's sales — 'vendor' (they are
      # merchant of record) or 'platform' (marketplace-facilitator rules).
      t.string :tax_remittance, null: false, default: 'vendor'

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
      t.datetime :deleted_at
    end

    add_index :spree_vendors, [:store_id, :slug], unique: true
    add_index :spree_vendors, [:store_id, :status]
    add_index :spree_vendors, :deleted_at

    # Mobility table-backend translations, mirroring spree_collection_translations.
    create_table :spree_vendor_translations do |t|
      t.string :name
      t.text :about
      t.string :locale, null: false
      t.references :spree_vendor, null: false, index: false

      t.timestamps null: false
      t.datetime :deleted_at
    end

    add_index :spree_vendor_translations, :locale, name: 'index_spree_vendor_translations_on_locale'
    add_index :spree_vendor_translations, [:spree_vendor_id, :locale], unique: true,
                                                                      name: 'index_vendor_translations_on_vendor_and_locale'
  end
end
