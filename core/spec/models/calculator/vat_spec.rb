require 'spec_helper'

describe Spree::Calculator::Vat do
  before(:each) do
    @configuration ||= Spree::AppConfiguration.find_or_create_by_name("Default configuration")
  end

  let(:tax_category) { Factory(:tax_category, :tax_rates => []) }
  let(:vat_rate) { Factory(:tax_rate, :amount => 0.15, :tax_category_id => tax_category.id) }
  let(:calculator) { Spree::Calculator::Vat.new(:calculable => vat_rate) }

  context ".compute" do
    let(:order) { mock_model Spree::Order, :line_items => [Factory(:line_item, :price => 20.0), Factory(:line_item, :price => 40.0)], :adjustments => [] }

    context "when rate does not belong to the default tax category" do
      before { vat_rate.tax_category.stub(:is_default => false) }

      it "should compute correctly when one product has matching tax category" do
        order.line_items[0].product.stub(:tax_category => vat_rate.tax_category)
        order.line_items[1].product.stub(:tax_category => nil)
        calculator.compute(order).should == 3.0
      end

      it "should return 0 when no products have tax categories" do
        order.line_items[0].product.stub(:tax_category => nil)
        order.line_items[1].product.stub(:tax_category => nil)
        calculator.compute(order).should == 0.0
      end

      context "with only adjustments" do
        before { order.stub :line_items => [] }

        it "should return 0 with single tax adjustment" do
          order.stub :adjustments => [Factory(:adjustment, :originator_type => "TaxRate")]
          calculator.compute(order).to_f.should == 0.0
        end

        it "should return 0 with shipping adjustment when Spree::Config[:shipment_inc_vat] is false" do
          Spree::Config.set :shipment_inc_vat => false
          order.stub :adjustments => [Factory(:adjustment, :originator_type => "ShippingMethod")]
          calculator.compute(order).to_f.should == 0.0
        end

      end

    end

    context "when rate does belong to the default tax category" do
      before { vat_rate.tax_category.stub(:is_default => true) }

      it "should calculate correctly when one product has matching tax category" do
        order.line_items[0].product.stub(:tax_category => Factory(:tax_category))
        order.line_items[1].product.stub(:tax_category => vat_rate.tax_category)
        calculator.compute(order).to_f.should == 6.0
      end

      it "should calculate correctly when no products have tax categories" do
        order.line_items[0].product.stub(:tax_category => nil)
        order.line_items[1].product.stub(:tax_category => nil)
        calculator.compute(order).should == 9.0
      end

      context "with only adjustments" do
        before { order.stub :line_items => [] }

        it "should return 0 with single tax adjustment" do
          order.stub :adjustments => [Factory(:adjustment, :originator_type => "TaxRate")]
          calculator.compute(order).to_f.should == 0.0
        end

        it "should return 0 with shipping adjustment when Spree::Config[:shipment_inc_vat] is false" do
          Spree::Config.set :shipment_inc_vat => false
          order.stub :adjustments => [Factory(:adjustment, :originator_type => "ShippingMethod", :amount => 5)]
          calculator.compute(order).to_f.should == 0.0
        end

        it "should calculate correctly with shipping adjustment when Spree::Config[:shipment_inc_vat] is true" do
          pending
          Spree::Config.set :shipment_inc_vat => true
          order.stub :adjustments => [Factory(:adjustment, :originator_type => "ShippingMethod", :amount => 5)]
          calculator.compute(order).to_f.should == 0.75
        end

        it "should calculate correctly with single non-tax charge" do
          order.stub :adjustments => [Factory(:adjustment, :originator_type => "", :amount => 12)]
          calculator.compute(order).to_f.should == 1.8
        end

        it "should calculate correctly with single non-tax credit" do
          order.stub :adjustments => [Factory(:adjustment, :originator_type => "", :amount => -12)]
          calculator.compute(order).to_f.should == -1.8
        end
      end

    end

  end

  context ".calculate_tax_on variant" do
    let(:variant) { Factory :variant, :price => 20.0 }

    it "should calculate correctly" do
      variant.product.stub :effective_tax_rate => BigDecimal.new("0.2")

      Spree::Calculator::Vat.calculate_tax_on(variant).to_f.should == 4.0
    end
  end

  context ".calculate_tax_on product" do
    let(:product) { Factory :product, :price => 10.0 }

    it "should calculate correctly" do
      product.stub :effective_tax_rate => BigDecimal.new("0.2")

      Spree::Calculator::Vat.calculate_tax_on(product).to_f.should == 2.0
    end
  end
end

