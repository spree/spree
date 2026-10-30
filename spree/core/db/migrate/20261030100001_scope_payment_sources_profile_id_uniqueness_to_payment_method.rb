class ScopePaymentSourcesProfileIdUniquenessToPaymentMethod < ActiveRecord::Migration[8.1]
  def change
    remove_index :spree_payment_sources, [:type, :gateway_payment_profile_id],
                 unique: true, name: 'index_payment_sources_on_type_and_gateway_payment_profile_id'
    add_index :spree_payment_sources, [:type, :gateway_payment_profile_id, :payment_method_id],
              unique: true, name: 'index_payment_sources_on_type_profile_id_and_payment_method'
  end
end
