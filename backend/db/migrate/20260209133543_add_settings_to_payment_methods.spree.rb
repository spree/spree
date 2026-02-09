# This migration comes from spree (originally 20211203082008)
class AddSettingsToPaymentMethods < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_payment_methods do |t|
      if t.respond_to? :jsonb
        add_column :spree_payment_methods, :settings, :jsonb
      else
        add_column :spree_payment_methods, :settings, :json
      end
    end
  end
end
