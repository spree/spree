class CreateSpreeReturnAuthorizationReasons < ActiveRecord::Migration
  def change
    create_table :spree_return_authorization_reasons do |t|
      t.string :name
      t.boolean :active, default: true
      t.boolean :mutable, default: true

      t.timestamps
    end

    add_column :spree_return_authorizations, :return_authorization_reason_id, :integer
    add_index :spree_return_authorizations, :return_authorization_reason_id, name: 'index_return_authorizations_on_return_authorization_reason_id'
  end
end
