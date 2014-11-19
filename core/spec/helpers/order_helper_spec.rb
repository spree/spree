require 'spec_helper'

module Spree
  describe Spree::OrdersHelper, :type => :helper do
    # Regression test for #2518 + #2323
    it "truncates HTML correctly in product description" do
      product = double(:description => "<strong>" + ("a" * 95) + "</strong> This content is invisible.")
      expected = "<strong>" + ("a" * 95) + "</strong>..."
      expect(truncated_product_description(product)).to eq(expected)
    end
  end
end
