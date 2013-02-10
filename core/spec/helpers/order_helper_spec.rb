require 'spec_helper'

module Spree
  describe OrdersHelper do
    # Regression test for #2518 + #2323
    it "truncates HTML correctly in product description" do
      product = stub(:description => "<strong>" + ("a" * 95) + "</strong> This content is invisible.")
      expected = "<strong>" + ("a" * 95) + "</strong>..."
      truncated_product_description(product).should == expected
    end
  end
end
