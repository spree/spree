class CreateSpreeUserPaymentSources < ActiveRecord::Migration
  def change
    create_table :spree_user_payment_sources do |t|
      t.references :user, index: true, foreign_key: false
      t.references :payment_source, polymorphic: true, index: {name: "index_users_payment_sources"}
      t.boolean :default

      t.timestamps null: false
    end
  end
end
