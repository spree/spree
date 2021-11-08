module Spree
  module Api
    module Webhooks
      module ProductDecorator
        def discontinue!
          super
          queue_webhooks_requests!('product.discontinued')
        end
      end
    end
  end
end

Spree::Product.prepend(Spree::Api::Webhooks::ProductDecorator)

