class CreateSpreeCommissionLines < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_commission_lines do |t|
      t.references :order, null: false
      t.references :vendor, null: false
      # Exactly one of these two: the commissioned item, or the commissioned
      # delivery when the rate carries include_shipping. Their indexes are
      # declared below, unique.
      t.references :line_item, index: false
      t.references :fulfillment, index: false
      # Nullable: the rate is mutable config and may be deleted long after the
      # sale, but the line's snapshot below stays the record either way.
      t.references :commission_rate

      # Snapshot of what was applied, frozen at placement. A later rate change
      # never reaches an existing line.
      t.decimal :rate, precision: 8, scale: 5, null: false, default: 0
      t.string :kind, null: false # percentage | fixed
      # What the platform charges the seller.
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      # VAT on that commission — a separate B2B supply from the item sale.
      t.decimal :tax_amount, precision: 10, scale: 2, null: false, default: 0
      # The rate that tax was charged at, so the row explains its own figure
      # once the configuration behind it has moved on.
      t.decimal :tax_rate, precision: 8, scale: 5, null: false, default: 0
      t.decimal :total, precision: 10, scale: 2, null: false, default: 0
      t.string :currency, null: false

      # How the commission was treated for tax, in the vocabulary
      # Spree::TaxLine already uses — an invoice has to say why a fee was
      # zero-rated or reverse-charged, and there is no reason for the
      # marketplace's own invoices to speak a second language.
      #
      # One tax per line, deliberately: a marketplace fee is a single supply to
      # a single business. Should a fee ever attract two levies at once, these
      # columns are the ones that would move to child rows.
      t.string :taxability_reason
      # Where the fee was taxed — the seller's own jurisdiction, not the
      # shopper's, since the platform invoices the seller's business. Named
      # plainly so Spree::HasIsoGeography can validate and read them.
      t.string :country_code
      t.string :state_code

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps

      # Written portably rather than with num_nonnulls: the same schema has to
      # build on MySQL and SQLite.
      t.check_constraint '(line_item_id IS NULL) <> (fulfillment_id IS NULL)',
                         name: 'chk_spree_commission_lines_one_subject'
    end

    add_index :spree_commission_lines, [:vendor_id, :created_at]
    # Reporting asks "what did we charge, where, and how was it treated" —
    # the same questions Spree::TaxLine indexes for.
    add_index :spree_commission_lines, :taxability_reason
    add_index :spree_commission_lines, [:country_code, :state_code]
    # One commission per item, and per fulfillment, so a replayed placement
    # cannot double-charge a seller. Plain unique indexes rather than partial
    # ones: every adapter treats NULLs as distinct here, so the rows carrying
    # the other subject never collide.
    add_index :spree_commission_lines, :line_item_id, unique: true,
                                                      name: 'index_commission_lines_on_line_item'
    add_index :spree_commission_lines, :fulfillment_id, unique: true,
                                                        name: 'index_commission_lines_on_fulfillment'
  end
end
