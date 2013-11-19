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
        Spree::TaxRate.create(
          :amount => 1,
          :zone => create(:zone, :name => 'other_zone')
        )
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

        context "when there order has a different tax zone" do
          before do
            order.stub :tax_zone => create(:zone, :name => "Other Zone")
            order.stub :tax_address => tax_address
          end

          context "when the order has a tax_address" do
            let(:tax_address) { stub_model(Spree::Address) }

            context "when the tax is a VAT" do
              let(:included_in_price) { true }
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
              it { should == [rate] }
            end

            context "when the tax is not a VAT" do
              it { should == [rate] }
            end
          end
        end
      end
    end
  end

  context "adjust" do
    let(:order) { stub_model(Spree::Order) }
    let(:rate_1) { stub_model(Spree::TaxRate) }
    let(:rate_2) { stub_model(Spree::TaxRate) }

    before do
      Spree::TaxRate.stub :match => [rate_1, rate_2]
    end

    it "should apply adjustments for two tax rates to the order" do
      rate_1.should_receive(:adjust)
      rate_2.should_receive(:adjust)
      Spree::TaxRate.adjust(order)
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
    let(:country) { create(:country) }
    let(:zone) do
      zone = create(:zone, :name => "Country Zone", :default_tax => true, :zone_members => [])
      zone.zone_members.create(:zoneable => country)
      zone
    end

    before do
      @category    = Spree::TaxCategory.create :name => "Taxable Foo"
      @category2   = Spree::TaxCategory.create(:name => "Non Taxable")
      @calculator  = Spree::Calculator::DefaultTax.new
      @order       = Spree::Order.create!
      @rate        = Spree::TaxRate.create(
        :amount => 0.10,
        :calculator => @calculator,
        :tax_category => @category,
        :zone => zone
      )
      @taxable     = create(:product, :tax_category => @category)
      @nontaxable  = create(:product, :tax_category => @category2)
    end

    context "when order has no taxable line items" do
      before { @order.contents.add(@nontaxable.master, 1) }

      it "should not create a tax adjustment" do
        @rate.adjust(@order)
        @order.adjustments.tax.charge.count.should == 0
      end

      it "should not create a line item adjustment" do
        @rate.adjust(@order)
        @order.line_item_adjustments.count.should == 0
      end

      it "should not create a refund" do
        @rate.adjust(@order)
        @order.adjustments.credit.count.should == 0
      end
    end

    context "when order has one taxable line item" do
      context "when price includes tax" do
        before do 
          @rate.update_column(:included_in_price, true)
          @order.contents.add(@taxable.master, 1)
          # The above automatically creates an adjustment which needs to be cleared
          @order.all_adjustments.destroy_all
        end

        context "when zone is contained by default tax zone" do
          before { Spree::Zone.stub_chain :default_tax, :contains? => true }

          it "should create one included line item adjustment" do
            @rate.adjust(@order)
            @order.line_item_adjustments.count.should == 1
            @order.line_item_adjustments.first.included.should be_true
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

          it "should not create a line item adjustment" do
            @rate.adjust(@order)
            @order.line_item_adjustments.count.should == 0
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
        before do 
          @rate.update_column(:included_in_price, false)
          @order.contents.add(@taxable.master, 1)
          # The above automatically creates an adjustment which needs to be cleared
          @order.all_adjustments.destroy_all
        end

        it "should not create line item adjustment" do
          @rate.adjust(@order)
          @order.line_item_adjustments.count.should == 0
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
        @order.contents.add(@taxable.master, 1)
        @order.contents.add(@taxable2.master, 1)
        # The above automatically creates an adjustment which needs to be cleared
        @order.all_adjustments.destroy_all
      end

      context "when line item includes tax" do
        before { @rate.included_in_price = true }

        context "when zone is contained by default tax zone" do
          before { Spree::Zone.stub_chain :default_tax, :contains? => true }

          it "should create multiple price adjustments" do
            @rate.adjust(@order)
            @order.line_item_adjustments.count.should == 2
            expect(@order.line_item_adjustments.all? { |a| a.included? }).to be_true
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
            @order.line_item_adjustments.count.should == 0
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
          @order.line_item_adjustments.count.should == 0
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
