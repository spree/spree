Rails.application.config.after_initialize do
  Spree::Dependencies.current_store_finder = 'Spree::Stores::FindCurrent'

  Spree.metafields.enabled_resources << Spree::CustomDomain

  Spree::PermittedAttributes.store_attributes.push(
    :import_products_from_store_id,
    :import_payment_methods_from_store_id
  )

  if defined?(Spree::Admin)
    Spree.admin.partials.product_form_sidebar << 'spree/admin/products/form/stores'
  end

  # Multi-store setup
  # You need to set a wildcard `root_domain` on the store to enable multi-store setup
  # all new stores will be created in a subdomain of the root domain, eg. store1.localhost, store2.localhost, etc.
  Spree.root_domain = ENV.fetch('SPREE_ROOT_DOMAIN', 'localhost')
end
