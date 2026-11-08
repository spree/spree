class ScopePaymentSourcesProfileIdUniquenessToPaymentMethod < ActiveRecord::Migration[8.1]
  LEGACY_INDEX_NAME = 'index_payment_sources_on_type_and_gateway_payment_profile_id'.freeze
  INDEX_NAME = 'index_payment_sources_on_type_profile_id_and_payment_method'.freeze

  def up
    remove_index :spree_payment_sources, name: LEGACY_INDEX_NAME
    add_index :spree_payment_sources, [:type, :gateway_payment_profile_id, :payment_method_id],
              unique: true, name: INDEX_NAME
  end

  # The legacy index cannot come back once a buyer holds the same gateway profile under two
  # payment methods, which is what `up` exists to allow. Checked before anything is dropped so a
  # refusal leaves both indexes intact on MySQL, which has no transactional DDL.
  def down
    if cross_payment_method_duplicates?
      raise ActiveRecord::IrreversibleMigration,
            'Payment sources share a gateway_payment_profile_id across payment methods, which ' \
            'the globally unique index cannot represent. Reconcile those rows before rolling back.'
    end

    remove_index :spree_payment_sources, name: INDEX_NAME
    add_index :spree_payment_sources, [:type, :gateway_payment_profile_id],
              unique: true, name: LEGACY_INDEX_NAME
  end

  private

  # NULLs are distinct in a unique index, so only fully populated pairs could ever have collided.
  def cross_payment_method_duplicates?
    connection.select_value(<<~SQL).present?
      SELECT 1 FROM spree_payment_sources
      WHERE type IS NOT NULL AND gateway_payment_profile_id IS NOT NULL
      GROUP BY type, gateway_payment_profile_id
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
  end
end
