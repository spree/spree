require "spec_helper"

module Spree
  describe AnalyticsHelper do

    before :all do
      Spree::Dash::Config.app_id = 1
      Spree::Dash::Config.site_id = 2
    end

    it "includes jirafe configuration" do
      tags = helper.analytics_tags
      tags[:id].should be_kind_of String
      tags[:id].should eq "2"
    end

    describe "Tracking Tags Customizations" do
      before :each do
        @product = double(:name => "Fancy Pants",
                          :price => "19.99",
                          :sku => "1234",
                          :taxons => [double(:permalink => "clothing/pants")])

        @variant = double(:name => @product.name,
                          :price => @product.price,
                          :sku => @product.sku,
                          :product => @product)

        @order = double(:number => "R12345",
                        :total => "19.99",
                        :ship_total => "22.99",
                        :tax_total => "4.99",
                        :adjustment_total => "0.00",
                        :item_total => "1.99",
                        :cart? => false,
                        :complete? => false)

      end

      it "for @product" do
        assign :product, @product
        tags = helper.product_analytics_tags
        tags[:product][:name].should eq "Fancy Pants"
        tags[:product][:price].should eq "19.99"
        tags[:product][:sku].should eq "1234"
        tags[:product][:categories].first.should eq "clothing/pants"
      end

      it "for taxons" do
        assign :taxon, double(:permalink => "clothing/shirts")
        tags = helper.taxon_analytics_tags
        tags[:category][:name].should eq "clothing/shirts"
      end

      it "for keywords" do
        params[:keywords] = "rails"
        tags = helper.keywords_analytics_tags
        tags[:search][:keyword].should eq "rails"
      end

      it "escapes keywords" do
        Spree::Dash::Config.app_id = "test"
        Spree::Dash::Config.token = "test"
        Spree::Dash::Config.site_id " test"
        params[:keywords] = "\"funny><looking><keywords"
        tags = helper.spree_analytics
        tags.should_not include("funny><looking><keywords")
        tags.should include("%22funny%3E%3Clooking%3E%3Ckeywords")
      end

      it "for cart" do
        @order.should_receive(:cart?).and_return(true)
        assign :order, @order
        helper.should_receive(:products_for_order).and_return([{:name => "product1"}])
        tags = helper.cart_analytics_tags
        tags[:cart][:total].should eq "19.99"
        tags[:cart][:products].first[:name].should eq "product1"
      end

      it "for completed order" do
        @order.should_receive(:complete?).and_return(true)
        assign :order, @order
        helper.should_receive(:products_for_order).and_return([{:name => "product1"}])
        tags = helper.completed_analytics_tags
        tags[:confirm][:orderid].should eq "R12345"
        tags[:confirm][:total].should eq "19.99"
        tags[:confirm][:shipping].should eq "22.99"
        tags[:confirm][:tax].should eq "4.99"
        tags[:confirm][:discount].should eq "0.00"
        tags[:confirm][:subtotal].should eq "1.99"
        tags[:confirm][:products].first[:name].should eq "product1"
      end

      it "products_for_order" do
        line_item = double(:variant => @variant, :quantity => "4")
        assign :order, double(:line_items => [line_item])
        tags = helper.products_for_order
        tags.first[:name].should eq "Fancy Pants"
        tags.first[:price].should eq "19.99"
        tags.first[:sku].should eq "1234"
        tags.first[:qty].should eq "4"
        tags.first[:categories].first.should eq "clothing/pants"
      end
    end
  end
end
