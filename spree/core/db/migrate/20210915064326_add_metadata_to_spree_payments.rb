class AddMetadataToSpreePayments < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_payments do |t|
      if t.respond_to? :jsonb
        add_column :spree_payments, :metadata, :jsonb
      else
        add_column :spree_payments, :metadata, :json
      end
    end
  end
end
