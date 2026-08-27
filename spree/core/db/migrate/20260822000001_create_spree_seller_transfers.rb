class CreateSpreeSellerTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_seller_transfers do |t|
      t.references :store, null: false
      t.references :seller, null: false
      # The child order this earning came from. One earning per order — see the
      # partial index below.
      t.references :order, null: false
      # Nil until a payout sweeps this transfer up and settles it.
      t.references :payout, index: true
      # The earning this row reverses, when a refund gave money back.
      t.references :reversed_from, index: true
      # Which refund caused it. The reversal's natural key — see the index
      # below.
      t.references :refund, index: false

      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.string :currency, null: false
      # earning | refund_reversal
      t.string :kind, null: false
      t.string :status, null: false # no DB default: set by the creating workflow

      # Which provider moved (or recorded) the money, and what it called the
      # movement. A `system` transfer has no reference — the operator settles
      # offline.
      t.string :provider, null: false
      t.string :reference

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    add_index :spree_seller_transfers, [:seller_id, :currency, :status]
    add_index :spree_seller_transfers, [:seller_id, :created_at]

    # One reversal per refund. An order can be refunded many times, so the
    # order cannot be the key here — but a single refund must claw back once
    # however many times its event is delivered, and two refunds arriving
    # together must not each read the same untouched earning and both take the
    # whole of it.
    add_index :spree_seller_transfers, :refund_id, unique: true,
                                                  name: 'index_seller_transfers_on_refund'

    # A re-fired fulfillment event must find the existing row rather than
    # credit the seller twice. Reversals are deliberately outside the
    # order constraint: an order can be refunded more than once.
    if connection.supports_partial_index?
      add_index :spree_seller_transfers, :order_id, unique: true,
                                                    where: "kind = 'earning'",
                                                    name: 'index_seller_transfers_on_order_earning'
    else
      # MySQL and MariaDB have no partial index, and functional indexes are
      # MySQL-only — MariaDB rejects the expression outright. A stored
      # generated column is the one spelling both accept.
      #
      # Null for anything that is not an earning, because null is what a
      # unique index treats as distinct from every other null: earnings
      # collide on their order, and any number of reversals sit alongside
      # them without colliding at all. Deliberately not the row's own id for
      # the other kinds — MySQL refuses a generated column that reads the
      # auto-increment key, which is what CI found.
      execute <<~SQL.squish
        ALTER TABLE spree_seller_transfers
        ADD COLUMN earning_key BIGINT
        AS (CASE WHEN kind = 'earning' THEN order_id ELSE NULL END) STORED
      SQL

      add_index :spree_seller_transfers, :earning_key, unique: true,
                                                       name: 'index_seller_transfers_on_order_earning'
    end

    # A provider's own id for the movement, unique where one exists: a retry
    # whose idempotency key returned the same external transfer must re-sync
    # this row rather than create a second.
    if connection.supports_partial_index?
      add_index :spree_seller_transfers, [:provider, :reference], unique: true,
                                                                 where: 'reference IS NOT NULL',
                                                                 name: 'index_seller_transfers_on_provider_reference'
    else
      add_index :spree_seller_transfers, [:provider, :reference],
                name: 'index_seller_transfers_on_provider_reference'
    end
  end
end
