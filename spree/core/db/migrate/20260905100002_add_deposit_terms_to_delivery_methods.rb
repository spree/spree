class AddDepositTermsToDeliveryMethods < ActiveRecord::Migration[8.1]
  def change
    # What a merchant asks for up front on this shipment type. Nil is
    # pay-in-full, which is every method today. A column beside markup_flat
    # and markup_percent rather than a preference: it is merchant
    # configuration of the method itself, not per-provider credentials.
    add_column :spree_delivery_methods, :deposit_percentage, :decimal, precision: 5, scale: 2
    # What the merchant calls the rest — "Before shipping", "On arrival".
    # A label, never a date: real due dates are Enterprise terms.
    add_column :spree_delivery_methods, :balance_due_label, :string
  end
end
