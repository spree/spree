class CreateSpreeSellerPayouts < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_seller_payouts do |t|
      t.references :store, null: false
      t.references :seller, null: false

      # The sum of the transfers this payout settles, fixed when it is
      # assembled. Not derived on read: a settled payout is a record of what
      # was sent, and later reversals belong to the next period rather than
      # rewriting a closed one.
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.string :currency, null: false
      t.string :status, null: false # no DB default: set by the creating workflow

      # What this payout covers, so a statement can name its period.
      t.datetime :period_start
      t.datetime :period_end

      t.string :provider, null: false
      t.string :reference

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    add_index :spree_seller_payouts, [:seller_id, :currency, :status]
    add_index :spree_seller_payouts, [:seller_id, :created_at]

    if connection.supports_partial_index?
      add_index :spree_seller_payouts, [:provider, :reference], unique: true,
                                                               where: 'reference IS NOT NULL',
                                                               name: 'index_seller_payouts_on_provider_reference'
    else
      # Unique here too. MySQL and MariaDB have no partial index, but they do
      # treat every NULL as distinct from every other — so the rows that carry
      # no reference (the built-in provider writes none) sit alongside each
      # other freely while a provider's own id stays unrepeatable, which is
      # what stops a retry recording the same movement twice.
      add_index :spree_seller_payouts, [:provider, :reference], unique: true,
                name: 'index_seller_payouts_on_provider_reference'
    end
  end
end
