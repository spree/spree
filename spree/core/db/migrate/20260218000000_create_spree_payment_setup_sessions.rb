class CreateSpreePaymentSetupSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_payment_setup_sessions do |t|
      t.references :customer, index: true
      t.references :payment_method, null: false, index: true
      t.references :payment_source, polymorphic: true, index: { name: 'idx_spree_pss_on_payment_source' }
      t.string :status, null: false
      t.string :external_id
      t.string :external_client_secret
      if t.respond_to? :jsonb
        t.jsonb :external_data
      else
        t.json :external_data
      end
      t.datetime :deleted_at, index: true
      t.timestamps
    end

    add_index :spree_payment_setup_sessions, :status
    add_index :spree_payment_setup_sessions, [:external_id, :payment_method_id],
              unique: true,
              name: 'idx_spree_pss_unique_external_id_per_pm'
  end
end
