require 'spec_helper'

describe Spree::TaxRate do

  context 'validation' do
    it { should validate_presence_of(:tax_category_id) }
  end

  context "match" do
    let(:order) { create(:order) }
    let(:country) { create(:country) }
    let(:tax_category) { create(:tax_category) }
    let(:calculator) { Spree::Calculator::FlatRate.new }


    it "should return an empty array when tax_zone is nil" do
      order.stub :tax_zone => nil
      Spree::TaxRate.match(order).should == []
    end

    context "when no rate zones match the tax zone" do
      before do
        Spree::TaxRate.create({:amount => 1, :zone => create(:zone, :name => 'other_zone')}, :without_protection => true)
      end

      context "when there is no default tax zone" do
        before do
          @zone = create(:zone, :name => "Country Zone", :default_tax => false, :zone_members => [])
          @zone.zone_members.create(:zoneable => country)
        end

        it "should return an emtpy array" do
          order.stub :tax_zone => @zone
          Spree::TaxRate.match(order).should == []
        end

        it "should return the rate that matches the rate zone" do
          rate = Spree::TaxRate.create({ :amount => 1, :zone => @zone, :tax_category => tax_category,
                                       :calculator => calculator }, :without_protection => true)

          order.stub :tax_zone => @zone
          Spree::TaxRate.match(order).should == [rate]
        end

        it "should return all rates that match the rate zone" do
          rate1 = Spree::TaxRate.create({:amount => 1, :zone => @zone, :tax_category => tax_category,
                                        :calculator => calculator}, :without_protection => true)
          rate2 = Spree::TaxRate.create({:amount => 2, :zone => @zone, :tax_category => tax_category,
                                        :calculator => Spree::Calculator::FlatRate.new}, :without_protection => true)

          order.stub :tax_zone => @zone
          Spree::TaxRate.match(order).should == [rate1, rate2]
        end

        context "when the tax_zone is contained within a rate zone" do
          before do
            sub_zone = create(:zone, :name => "State Zone", :zone_members => [])
            sub_zone.zone_members.create(:zoneable => create(:state, :country => country))
            order.stub :tax_zone => sub_zone
            @rate = Spree::TaxRate.create({:amount => 1, :zone => @zone, :tax_category => tax_category,
                                          :calculator => calculator}, :without_protection => true)
          end

          it "should return the rate zone" do
            Spree::TaxRate.match(order).should == [@rate]
          end
        end

      end

      context "when there is a default tax zone" do
        before do
          @zone = create(:zone, :name => "Country Zone", :default_tax => true, :zone_members => [])
          @zone.zone_members.create(:zoneable => country)
        end

        context "when there order has a different tax zone" do
          before { order.stub :tax_zone => create(:zone, :name => "Other Zone") }

          it "should return the rates associated with the default tax zone" do
            rate = Spree::TaxRate.create({:amount => 1, :zone => @zone, :tax_category => tax_category,
                                         :calculator => calculator}, :without_protection => true)

            Spree::TaxRate.match(order).should == [rate]
          end
        end

      end

    end

  end

  context "default" do
    let(:tax_category) { create(:tax_category) }
    let(:country) { create(:country) }
    let(:calculator) { Spree::Calculator::FlatRate.new }

    context "when there is no default tax_category" do
      before { tax_category.is_default = false }

      it "should return 0" do
        Spree::TaxRate.default.should == 0
      end
    end

    context "when there is a default tax_category" do
      before { tax_category.update_attribute :is_default, true }

      context "when the default category has tax rates in the default tax zone" do
        before(:each) do
          Spree::Config[:default_country_id] = country.id
          @zone = create(:zone, :name => "Country Zone", :default_tax => true)
          @zone.zone_members.create(:zoneable => country)
          rate = Spree::TaxRate.create({:amount => 1, :zone => @zone, :tax_category => tax_category, :calculator => calculator}, :without_protection => true)
        end

        it "should return the correct tax_rate" do
          Spree::TaxRate.default.to_f.should == 1.0
        end
      end

      context "when the default category has no tax rates in the default tax zone" do
        it "should return 0" do
          Spree::TaxRate.default.should == 0
        end
      end
    end
  end

  context "#adjust" do
    before do
      @category    = Spree::TaxCategory.create :name => "Taxable Foo"
      @category2   = Spree::TaxCategory.create(:name => "Non Taxable")
      @calculator  = Spree::Calculator::DefaultTax.new
      @rate        = Spree::TaxRate.create({:amount => 0.10, :calculator => @calculator, :tax_category => @category}, :without_protection => true)
      @order       = Spree::Order.create!
      @taxable     = create(:product, :tax_category => @category)
      @nontaxable  = create(:product, :tax_category => @category2)
    end

    context "when order has no taxable line items" do
      before { @order.add_variant @nontaxable.master }

      it "should not create a tax adjustment" do
        @rate.adjust(@order)
        @order.adjustments.tax.charge.count.should == 0
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
        before { @rate.included_in_price = true }

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
            @order.adjustments.tax.charge.count.should == 0
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
            @order.adjustments.tax.charge.count.should == 0
          end
        end

      end

      context "when price does not include tax" do
        before { @rate.included_in_price = false }

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
          @order.adjustments.tax.charge.count.should == 1
        end
      end

    end

    context "when order has multiple taxable line items" do
      before do
        @taxable2 = create(:product, :tax_category => @category)
        @order.add_variant @taxable.master
        @order.add_variant @taxable2.master
      end

      context "when price includes tax" do
        before { @rate.included_in_price = true }

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
            @order.adjustments.tax.charge.count.should == 0
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
            @order.adjustments.tax.charge.count.should == 0
          end
        end

      end

      context "when price does not include tax" do
        before { @rate.included_in_price = false }

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
          @order.adjustments.tax.charge.count.should == 1
        end
      end

    end

  end

end
