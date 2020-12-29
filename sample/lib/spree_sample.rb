require 'spree_core'
require 'spree/sample'

module SpreeSample
  class Engine < Rails::Engine
    engine_name 'spree_sample'

    # Needs to be here so we can access it inside the tests
    def self.load_samples
      Spree::Sample.load_sample('addresses')
      Spree::Sample.load_sample('zones')
      Spree::Sample.load_sample('payment_methods')
      Spree::Sample.load_sample('shipping_categories')
      Spree::Sample.load_sample('shipping_methods')
      Spree::Sample.load_sample('tax_categories')
      Spree::Sample.load_sample('tax_rates')
      Spree::Sample.load_sample('taxonomies')
      Spree::Sample.load_sample('promotions')

      Spree::Sample.load_sample('products')
      Spree::Sample.load_sample('taxons')
      Spree::Sample.load_sample('option_types')
      Spree::Sample.load_sample('option_values')
      Spree::Sample.load_sample('product_properties')
      Spree::Sample.load_sample('prototypes')
      Spree::Sample.load_sample('variants')
      Spree::Sample.load_sample('stock')

      Spree::Sample.load_sample('orders')
      Spree::Sample.load_sample('adjustments')
      Spree::Sample.load_sample('payments')
      Spree::Sample.load_sample('reimbursements')
      Spree::Sample.load_sample('return_authorization_reasons')
    end
  end
end
