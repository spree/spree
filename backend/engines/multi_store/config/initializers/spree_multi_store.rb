Rails.application.config.after_initialize do
  # Override store finder to use URL-based resolution
  Spree::Dependencies.current_store_finder = 'Spree::Stores::FindCurrent'

  # Extend Store with multi-store methods (custom domains, URL resolution, imports)
  Spree::Store.include Spree::Store::MultiStoreMethods

  # Replace StoreScopedResource with MultiStoreResource on shared models
  # MultiStoreResource adds validation that at least one store is assigned
  Spree::Product.include Spree::MultiStoreResource
  Spree::PaymentMethod.include Spree::MultiStoreResource
  Spree::Promotion.include Spree::MultiStoreResource

  # Add import permitted attributes for store creation
  Spree::PermittedAttributes.store_attributes.push(
    :import_products_from_store_id,
    :import_payment_methods_from_store_id
  )

  # Add CustomDomain to metafields enabled resources if metafields are available
  if Spree::Config.respond_to?(:metafields_enabled_resources)
    Spree::Config.metafields_enabled_resources << Spree::CustomDomain unless Spree::Config.metafields_enabled_resources.include?(Spree::CustomDomain)
  end
end
