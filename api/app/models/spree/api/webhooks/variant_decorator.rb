module Spree
  module Api
    module Webhooks
      module VariantDecorator
        def discontinue!
          super
          queue_webhooks_requests!('variant.discontinued')
        end
      end
    end
  end
end

Spree::Variant.prepend(Spree::Api::Webhooks::VariantDecorator)
