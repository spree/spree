require 'spec_helper'

describe Spree::TaxRate do

  context 'validation' do
    it { should validate_presence_of(:tax_category_id) }
  end

  context "match" do
    let(:zone) { Factory(:zone) }
    let(:order) { Factory(:order) }
    let(:tax_category) { Factory(:tax_category) }
    let(:calculator) { Spree::Calculator::FlatRate.new }

    it "should return an empty array when tax_zone is nil" do
      order.stub :tax_zone => nil
      Spree::TaxRate.match(order).should == []
    end

    it "should return an emtpy array when no rate zones match the tax_zone" do
      Spree::TaxRate.create :amount => 1, :zone => Factory(:zone, :name => 'other_zone')
      order.stub :tax_zone => zone
      Spree::TaxRate.match(order).should == []
    end

    it "should return the rate that matches the rate zone" do
      rate = Spree::TaxRate.create :amount => 1, :zone => zone, :tax_category => tax_category,
                                   :calculator => calculator
      order.stub :tax_zone => zone
      Spree::TaxRate.match(order).should == [rate]
    end

    it "should return all rates that match the rate zone" do
      rate1 = Spree::TaxRate.create :amount => 1, :zone => zone, :tax_category => tax_category,
                                    :calculator => calculator
      rate2 = Spree::TaxRate.create :amount => 2, :zone => zone, :tax_category => tax_category,
                                    :calculator => calculator
      order.stub :tax_zone => zone
      Spree::TaxRate.match(order).should == [rate1, rate2]
    end
  end

  context "#adjust" do
    before do
      @category    = Spree::TaxCategory.create :name => "Taxable Foo"
      @category2   = Spree::TaxCategory.create(:name => "Non Taxable")
      @calculator  = Spree::Calculator::DefaultTax.new
      @rate        = Spree::TaxRate.create(:amount => 0.10, :calculator => @calculator, :tax_category => @category)
      @order       = Spree::Order.create!
      @taxable     = Factory(:product, :tax_category => @category)
      @nontaxable  = Factory(:product, :tax_category => @category2)
    end

    context "when order has no taxable line items" do
      before { @order.add_variant @nontaxable.master }

      it "should not create a tax adjustment" do
        @rate.adjust(@order)
        @order.adjustments.tax.count.should == 0
      end

      it "should not create a price adjustment" do
        @rate.adjust(@order)
        @order.price_adjustments.count.should == 0
      end

      it "should not create a refund" do
        @rate.adjust(@order)
        @order.adjustments.credit.count.should == 0
      end
    end

    context "when order has one taxable line item" do
      before { @order.add_variant @taxable.master }

      context "when price includes tax" do
        before { @rate.inc_tax = true }

        context "when zone is contained by default tax zone" do
          before { Spree::Zone.stub_chain :default_tax, :contains? => true }

          it "should create one price adjustment" do
            @rate.adjust(@order)
            @order.price_adjustments.count.should == 1
          end

          it "should not create a tax refund" do
            @rate.adjust(@order)
            @order.adjustments.credit.count.should == 0
          end

          it "should not create a tax adjustment" do
            @rate.adjust(@order)
            @order.adjustments.tax.count.should == 0
          end
        end

        context "when zone is not contained by default tax zone" do
          before { Spree::Zone.stub_chain :default_tax, :contains? => false }

          it "should not create a price adjustment" do
            @rate.adjust(@order)
            @order.price_adjustments.count.should == 0
          end

          it "should create a tax refund" do
            @rate.adjust(@order)
            @order.adjustments.credit.count.should == 1
          end

          it "should not create a tax adjustment" do
            @rate.adjust(@order)
            @order.adjustments.tax.count.should == 0
          end
        end

      end

      context "when price does not include tax" do
        before { @rate.inc_tax = false }

        it "should not create price adjustment" do
          @rate.adjust(@order)
          @order.price_adjustments.count.should == 0
        end

        it "should not create a tax refund" do
          @rate.adjust(@order)
          @order.adjustments.credit.count.should == 0
        end

        it "should create a tax adjustment" do
          @rate.adjust(@order)
          @order.adjustments.tax.count.should == 1
        end
      end

    end

    context "when order has multiple taxable line items" do
      before do
        @taxable2 = Factory(:product, :tax_category => @category)
        @order.add_variant @taxable.master
        @order.add_variant @taxable2.master
      end

      context "when price includes tax" do
        before { @rate.inc_tax = true }

        context "when zone is contained by default tax zone" do
          before { Spree::Zone.stub_chain :default_tax, :contains? => true }

          it "should create multiple price adjustments" do
            @rate.adjust(@order)
            @order.price_adjustments.count.should == 2
          end

          it "should not create a tax refund" do
            @rate.adjust(@order)
            @order.adjustments.credit.count.should == 0
          end

          it "should not create a tax adjustment" do
            @rate.adjust(@order)
            @order.adjustments.tax.count.should == 0
          end
        end

        context "when zone is not contained by default tax zone" do
          before { Spree::Zone.stub_chain :default_tax, :contains? => false }

          it "should not create a price adjustment" do
            @rate.adjust(@order)
            @order.price_adjustments.count.should == 0
          end

          it "should create a single tax refund" do
            @rate.adjust(@order)
            @order.adjustments.credit.count.should == 1
          end

          it "should not create a tax adjustment" do
            @rate.adjust(@order)
            @order.adjustments.tax.count.should == 0
          end
        end

      end

      context "when price does not include tax" do
        before { @rate.inc_tax = false }

        it "should not create a price adjustment" do
          @rate.adjust(@order)
          @order.price_adjustments.count.should == 0
        end

        it "should not create a tax refund" do
          @rate.adjust(@order)
          @order.adjustments.credit.count.should == 0
        end

        it "should create a single tax adjustment" do
          @rate.adjust(@order)
          @order.adjustments.tax.count.should == 1
        end
      end

    end

  end

end
