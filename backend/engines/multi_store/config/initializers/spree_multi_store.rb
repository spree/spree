Rails.application.config.after_initialize do
  # Override store finder to use URL-based resolution
  Spree::Dependencies.current_store_finder = 'Spree::Stores::FindCurrent'

  # Include Store with multi-store methods (custom domains, URL resolution, imports)
  # include is needed to fire the `included` block (associations, scopes, callbacks)
  Spree::Store.include Spree::Store::MultiStoreMethods

  # Prepend overrides for instance methods that are defined in core's Store model
  # (included module methods don't override methods defined directly on the class)
  Spree::Store.prepend Spree::Store::MultiStoreOverrides

  # Override the singleton .current method defined in core's Store model
  # (singleton methods take precedence over methods from included/prepended modules)
  Spree::Store.define_singleton_method(:current) do |url = nil|
    if url.present?
      Spree.current_store_finder.new(url: url).execute
    else
      Spree::Current.store
    end
  end

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

  # Register admin partials for multi-store UI
  if defined?(Spree::Admin)
    Spree.admin.partials.product_form_sidebar << 'spree/admin/products/form/stores'
  end

  # Add CustomDomain to metafields enabled resources if metafields are available
  if Spree::Config.respond_to?(:metafields_enabled_resources)
    Spree::Config.metafields_enabled_resources << Spree::CustomDomain unless Spree::Config.metafields_enabled_resources.include?(Spree::CustomDomain)
  end
end
