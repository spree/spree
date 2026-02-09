# This migration comes from spree (originally 20220113052823)
class CreatePaymentSources < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_payment_sources do |t|
      t.string :gateway_payment_profile_id
      t.string :type, index: true

      t.references :payment_method, index: true, foreign_key: { to_table: :spree_payment_methods }
      t.references :user, index: true, foreign_key: { to_table: :spree_users }

      if t.respond_to? :jsonb
        t.jsonb :public_metadata
        t.jsonb :private_metadata
      else
        t.json :public_metadata
        t.json :private_metadata
      end

      t.index [:type, :gateway_payment_profile_id], unique: true, name: 'index_payment_sources_on_type_and_gateway_payment_profile_id'
      t.timestamps
    end
  end
end
