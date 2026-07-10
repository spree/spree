# Default Getting Started tasks shown on the admin dashboard.
# See Spree::Stores::SetupTasks for how to add or remove tasks.
Rails.application.config.after_initialize do
  Spree.store_setup_tasks.add :setup_payment_method,
    position: 10,
    done: ->(store) { store.payment_method_setup? }

  Spree.store_setup_tasks.add :add_products,
    position: 20,
    done: ->(store) { store.products.any? }

  Spree.store_setup_tasks.add :set_customer_support_email,
    position: 30,
    done: ->(store) { store.customer_support_email.present? }

  Spree.store_setup_tasks.add :setup_taxes_collection,
    position: 40,
    done: ->(_store) { Spree::TaxRate.any? }

  Spree.store_setup_tasks.add :setup_storefront,
    position: 50,
    done: ->(store) { store.storefront_setup? }
end
