module Spree
  class ShippingCategory < Spree::Base
    include Spree::UniqueName
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    with_options inverse_of: :shipping_category do
      has_many :products
      has_many :shipping_method_categories
    end
    has_many :shipping_methods, through: :shipping_method_categories
  end
end
