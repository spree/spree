# This migration comes from spree (originally 20210915064326)
class AddMetadataToSpreePayments < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_payments do |t|
      if t.respond_to? :jsonb
        add_column :spree_payments, :public_metadata, :jsonb
        add_column :spree_payments, :private_metadata, :jsonb
      else
        add_column :spree_payments, :public_metadata, :json
        add_column :spree_payments, :private_metadata, :json
      end
    end
  end
end
