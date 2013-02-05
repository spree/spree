require 'truncate_html'
require 'app/helpers/truncate_html_helper'

module Spree
  module OrdersHelper
    include TruncateHtmlHelper

    def truncated_product_description(product)
      truncate_html(raw(product.description))
    end
  end
end

