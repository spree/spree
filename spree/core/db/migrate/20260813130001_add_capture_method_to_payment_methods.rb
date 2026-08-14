class AddCaptureMethodToPaymentMethods < ActiveRecord::Migration[8.1]
  # When a payment method charges rather than only authorizes, replacing the
  # auto_capture boolean — which could not express "charge this one on
  # dispatch". Nullable keeps the meaning the boolean already had: no value
  # means defer to the store.
  #
  # A column rather than a preference because this is a property of every
  # payment method, like `active` and `position` — the preferences blob holds
  # per-provider gateway credentials, and it is neither queryable nor separable
  # from the provider configuration form.
  #
  # Existing auto_capture values are carried over by
  # spree:migrate_capture_methods, never here.
  def change
    add_column :spree_payment_methods, :capture_method, :string
  end
end
