require 'truncate_html'
require 'app/helpers/truncate_html_helper'

module Spree
  module OrdersHelper
    include TruncateHtmlHelper

    def truncated_product_description(product)
      ActiveSupport::Deprecation.warn "truncated_product_description(product) is deprecated and may be removed from future releases, use truncated_description(product.description) instead.", caller
      truncated_description(product.description)
    end

    def truncated_description(text)
      truncate_html(raw(text))
    end
  end
end

