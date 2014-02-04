class AddAutoCaptureToPaymentMethods < ActiveRecord::Migration
  def change
    add_column :spree_payment_methods, :auto_capture, :boolean
  end
end
