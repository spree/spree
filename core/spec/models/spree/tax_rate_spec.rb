require 'spec_helper'

describe Spree::TaxRate do
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
        Spree::TaxRate.create(:amount => 1, :zone => create(:zone))
      end

      context "when there is no default tax zone" do
        before do
          @zone = create(:zone, :name => "Country Zone", :default_tax => false, :zone_members => [])
          @zone.zone_members.create(:zoneable => country)
        end

        it "should return an empty array" do
          order.stub :tax_zone => @zone
          Spree::TaxRate.match(order).should == []
        end

        it "should return the rate that matches the rate zone" do
          rate = Spree::TaxRate.create(
            :amount => 1,
            :zone => @zone,
            :tax_category => tax_category,
            :calculator => calculator
          )

          order.stub :tax_zone => @zone
          Spree::TaxRate.match(order).should == [rate]
        end

        it "should return all rates that match the rate zone" do
          rate1 = Spree::TaxRate.create(
            :amount => 1,
            :zone => @zone,
            :tax_category => tax_category,
            :calculator => calculator
          )

          rate2 = Spree::TaxRate.create(
            :amount => 2,
            :zone => @zone,
            :tax_category => tax_category,
            :calculator => Spree::Calculator::FlatRate.new
          )

          order.stub :tax_zone => @zone
          Spree::TaxRate.match(order).should == [rate1, rate2]
        end

        context "when the tax_zone is contained within a rate zone" do
          before do
            sub_zone = create(:zone, :name => "State Zone", :zone_members => [])
            sub_zone.zone_members.create(:zoneable => create(:state, :country => country))
            order.stub :tax_zone => sub_zone
            @rate = Spree::TaxRate.create(
              :amount => 1,
              :zone => @zone,
              :tax_category => tax_category,
              :calculator => calculator
            )
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

        let(:included_in_price) { false }
        let!(:rate) do
          Spree::TaxRate.create(:amount => 1,
                                :zone => @zone,
                                :tax_category => tax_category,
                                :calculator => calculator,
                                :included_in_price => included_in_price)
        end

        subject { Spree::TaxRate.match(order) }

        context "when the order has the same tax zone" do
          before do
            order.stub :tax_zone => @zone
            order.stub :tax_address => tax_address
          end

          let(:tax_address) { stub_model(Spree::Address) }

          context "when the tax is not a VAT" do
            it { should == [rate] }
          end

          context "when the tax is a VAT" do
            let(:included_in_price) { true }
            it { should == [rate] }
          end
        end

        context "when the order has a different tax zone" do
          before do
            order.stub :tax_zone => create(:zone, :name => "Other Zone")
            order.stub :tax_address => tax_address
          end

          context "when the order has a tax_address" do
            let(:tax_address) { stub_model(Spree::Address) }

            context "when the tax is a VAT" do
              let(:included_in_price) { true }
              # The rate should match in this instance because:
              # 1) It's the default rate (and as such, a negative adjustment should apply)
              it { should == [rate] }
            end

            context "when the tax is not VAT" do
              it "returns no tax rate" do
                subject.should be_empty
              end
            end
          end

          context "when the order does not have a tax_address" do
            let(:tax_address) { nil}

            context "when the tax is a VAT" do
              let(:included_in_price) { true }
              # The rate should match in this instance because:
              # 1) The order has no tax address by this stage
              # 2) With no tax address, it has no tax zone
              # 3) Therefore, we assume the default tax zone
              # 4) This default zone has a default tax rate.
              it { should == [rate] }
            end

            context "when the tax is not a VAT" do
              it { should be_empty }
            end
          end
        end
      end
    end
  end

  context "adjust" do
    let(:order) { stub_model(Spree::Order) }
    let(:tax_category_1) { stub_model(Spree::TaxCategory) }
    let(:tax_category_2) { stub_model(Spree::TaxCategory) }
    let(:rate_1) { stub_model(Spree::TaxRate, :tax_category => tax_category_1) }
    let(:rate_2) { stub_model(Spree::TaxRate, :tax_category => tax_category_2) }

    context "with line items" do
      let(:line_item) do
        stub_model(Spree::LineItem, 
          :tax_category => tax_category_1,
          :variant => stub_model(Spree::Variant)
        )
      end

      let(:line_items) { [line_item] }

      before do
        Spree::TaxRate.stub :match => [rate_1, rate_2]
      end

      it "should apply adjustments for two tax rates to the order" do
        rate_1.should_receive(:adjust)
        rate_2.should_not_receive(:adjust)
        Spree::TaxRate.adjust(order, line_items)
      end
    end

    context "with shipments" do
      let(:shipments) { [stub_model(Spree::Shipment, :tax_category => tax_category_1)] }

      before do
        Spree::TaxRate.stub :match => [rate_1, rate_2]
      end

      it "should apply adjustments for two tax rates to the order" do
        rate_1.should_receive(:adjust)
        rate_2.should_not_receive(:adjust)
        Spree::TaxRate.adjust(order, shipments)
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
      before { tax_category.update_column :is_default, true }

      context "when the default category has tax rates in the default tax zone" do
        before(:each) do
          Spree::Config[:default_country_id] = country.id
          @zone = create(:zone, :name => "Country Zone", :default_tax => true)
          @zone.zone_members.create(:zoneable => country)
          rate = Spree::TaxRate.create(
            :amount => 1,
            :zone => @zone,
            :tax_category => tax_category,
            :calculator => calculator
          )
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
      @country = create(:country)
      @zone = create(:zone, :name => "Country Zone", :default_tax => true, :zone_members => [])
      @zone.zone_members.create(:zoneable => @country)
      @category    = Spree::TaxCategory.create :name => "Taxable Foo"
      @category2   = Spree::TaxCategory.create(:name => "Non Taxable")
      @rate1        = Spree::TaxRate.create(
        :amount => 0.10,
        :calculator => Spree::Calculator::DefaultTax.create,
        :tax_category => @category,
        :zone => @zone
      )
      @rate2       = Spree::TaxRate.create(
        :amount => 0.05,
        :calculator => Spree::Calculator::DefaultTax.create,
        :tax_category => @category,
        :zone => @zone
      )
      @order       = Spree::Order.create!
      @taxable     = create(:product, :tax_category => @category)
      @nontaxable  = create(:product, :tax_category => @category2)
    end

    context "not taxable line item " do
      let!(:line_item) { @order.contents.add(@nontaxable.master, 1) }

      it "should not create a tax adjustment" do
        Spree::TaxRate.adjust(@order, @order.line_items)
        line_item.adjustments.tax.charge.count.should == 0
      end

      it "should not create a refund" do
        Spree::TaxRate.adjust(@order, @order.line_items)
        line_item.adjustments.credit.count.should == 0
      end
    end

    context "taxable line item" do
      let!(:line_item) { @order.contents.add(@taxable.master, 1) }

      context "when price includes tax" do
        before do
          @rate1.update_column(:included_in_price, true)
          @rate2.update_column(:included_in_price, true)
          Spree::TaxRate.store_pre_tax_amount(line_item, [@rate1, @rate2])
        end

        context "when zone is contained by default tax zone" do
          it "should create two adjustments, one for each tax rate" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            line_item.adjustments.count.should == 2
          end

          it "should not create a tax refund" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            line_item.adjustments.credit.count.should == 0
          end
        end

        context "when order's zone is neither the default zone, or included in the default zone, but matches the rate's zone" do
          before do
            # With no zone members, this zone will not contain anything
            # Previously:
            # Zone.stub_chain :default_tax, :contains? => false
            @zone.zone_members.delete_all
          end
          it "should create an adjustment" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            line_item.adjustments.charge.count.should == 2
          end

          it "should not create a tax refund for each tax rate" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            line_item.adjustments.credit.count.should == 0
          end
        end

        context "when order's zone does not match default zone, is not included in the default zone, AND does not match the rate's zone" do
          before do
            @new_zone = create(:zone, :name => "New Zone", :default_tax => false)
            @new_country = create(:country, :name => "New Country")
            @new_zone.zone_members.create(:zoneable => @new_country)
            @order.ship_address = create(:address, :country => @new_country)
            @order.save
          end

          it "should not create positive adjustments" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            line_item.adjustments.charge.count.should == 0
          end

          it "should create a tax refund for each tax rate" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            line_item.adjustments.credit.count.should == 2
          end
        end

        context "when price does not include tax" do
          before do
            @order.stub :tax_zone => @zone

            [@rate1, @rate2].each do |rate|
              rate.included_in_price = false
              rate.zone = @zone
              rate.save
            end
          end

          it "should create an adjustment" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            line_item.adjustments.count.should == 2
          end

          it "should not create a tax refund" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            line_item.adjustments.credit.count.should == 0
          end
        end

        context "when two rates apply" do
          before do
            @price_before_taxes = line_item.price / (1 + @rate1.amount + @rate2.amount)
            # Use the same rounding method as in DefaultTax calculator
            @price_before_taxes = BigDecimal.new(@price_before_taxes).round(2, BigDecimal::ROUND_HALF_UP)
            line_item.update_column(:pre_tax_amount, @price_before_taxes)
            # Clear out any previously automatically-applied adjustments
            @order.all_adjustments.delete_all
            @rate1.adjust(@order, line_item)
            @rate2.adjust(@order, line_item)
          end

          it "should create two price adjustments" do
            @order.line_item_adjustments.count.should == 2
          end

          it "price adjustments should be accurate" do
            included_tax = @order.line_item_adjustments.sum(:amount)
            expect(@price_before_taxes + included_tax).to eq(line_item.price)
          end
        end
      end
    end
  end
end
