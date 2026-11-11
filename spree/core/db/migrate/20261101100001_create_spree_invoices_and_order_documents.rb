class CreateSpreeInvoicesAndOrderDocuments < ActiveRecord::Migration[8.1]
  # Invoices, consumers' invoice requests and other order paperwork
  # (docs/plans/6.1-invoices-and-receipts.md, docs/plans/6.1-b2b-order-documents.md).
  # Files live in Active Storage; these rows hold what a list, a filter and an
  # accountant need without opening them.
  def change
    create_table :spree_invoices do |t|
      t.references :store, null: false, index: false
      # Indexed by the unique index below, which leads with these columns.
      t.references :issuer, polymorphic: true, null: false, index: false
      t.references :order, index: false
      t.references :seller_payout
      t.references :original_invoice
      t.references :uploaded_by, polymorphic: true, index: false
      t.string :kind, null: false
      t.string :source, null: false
      t.string :number, null: false
      t.date :issued_on, null: false
      t.date :supplied_on
      t.string :currency, null: false
      # Money columns are decimal(19, 4), as everywhere since 6.0
      # (docs/plans/6.0-money-correctness.md): an uploaded invoice must hold
      # the amounts its PDF shows, three-decimal currencies included.
      t.decimal :net_total, precision: 19, scale: 4
      t.decimal :tax_total, precision: 19, scale: 4
      t.decimal :total, precision: 19, scale: 4, null: false
      t.string :external_reference
      t.datetime :sent_at

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    # An issuer's own numbering is unique per kind: an invoice and a credit
    # note may share a number in systems that keep separate series.
    add_index :spree_invoices, [:issuer_type, :issuer_id, :kind, :number], unique: true,
                                                                           name: 'idx_spree_invoices_on_issuer_kind_and_number'
    # The missing-invoice filter asks "has this order an invoice or receipt";
    # the accountants' list sorts a store's invoices by issue date.
    add_index :spree_invoices, [:order_id, :kind]
    add_index :spree_invoices, [:store_id, :issued_on]

    create_table :spree_invoice_requests do |t|
      t.references :store, null: false
      t.references :order, null: false
      t.references :customer
      t.references :billing_address
      t.references :invoice
      t.string :status, null: false
      t.string :company_name
      t.string :tax_id

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    # One open request per order, enforced where two clicks race.
    if connection.supports_partial_index?
      add_index :spree_invoice_requests, :order_id, unique: true, where: "status = 'open'",
                                                    name: 'idx_spree_invoice_requests_on_open_order'
    end

    create_table :spree_order_documents do |t|
      t.references :store, null: false
      t.references :order, null: false
      t.references :uploaded_by, polymorphic: true, index: false
      t.string :label, null: false
      t.boolean :customer_visible, null: false, default: false
      # A guest buyer has no account to record as the uploader.
      t.boolean :uploaded_by_customer, null: false, default: false

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end
  end
end
