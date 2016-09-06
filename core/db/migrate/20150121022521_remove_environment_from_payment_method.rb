class RemoveEnvironmentFromPaymentMethod < ActiveRecord::Migration[4.2]
  def up
    Spree::PaymentMethod.where('environment != ?', Rails.env).update_all(active: false)
    remove_column :spree_payment_methods, :environment
  end
end
