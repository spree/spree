require 'spec_helper'

module Spree
  describe ProductsHelper do
    include ProductsHelper

    let(:product) { create(:product) }

    context "#variant_price_diff" do
      before do
        @variant = create(:variant, :product => product)
      end

      it "should be correct positive value when variant is more than master" do
        product.price = 10
        @variant.price = 15
        helper.variant_price_diff(@variant).should == "(Add: $5.00)"
      end

      it "should be nil when variant is same as master" do
        product.price = 10
        @variant.price = 10
        helper.variant_price_diff(@variant).should be_nil
      end

      it "should be correct negative value when variant is less than master" do
        product.price = 15
        @variant.price = 10
        helper.variant_price_diff(@variant).should == "(Subtract: $5.00)"
      end
    end

    context "#product_description" do
      # Regression test for #1607
      it "renders a product description without excessive paragraph breaks" do
        product.description = %Q{
<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus a ligula leo. Proin eu arcu at ipsum dapibus ullamcorper. Pellentesque egestas orci nec magna condimentum luctus. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Ut ac ante et mauris bibendum ultricies non sed massa. Fusce facilisis dui eget lacus scelerisque eget aliquam urna ultricies. Duis et rhoncus quam. Praesent tellus nisi, ultrices sed iaculis quis, euismod interdum ipsum.</p>
<ul>
<li>Lorem ipsum dolor sit amet</li>
<li>Lorem ipsum dolor sit amet</li>
</ul>
        }
        description = product_description(product)
        description.strip.should == product.description.strip
      end

      it "renders a product description with automatic paragraph breaks" do
        product.description = %Q{
THIS IS THE BEST PRODUCT EVER!

"IT CHANGED MY LIFE" - Sue, MD}

        description = product_description(product)
        description.strip.should == %Q{<p>\nTHIS IS THE BEST PRODUCT EVER!</p>\\n\\n"IT CHANGED MY LIFE" - Sue, MD}
      end

    end
  end
end
