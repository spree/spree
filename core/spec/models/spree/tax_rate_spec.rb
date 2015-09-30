require 'spec_helper'

describe Spree::TaxRate, :type => :model do
  context "match" do
    let(:order) { create(:order) }
    let(:country) { create(:country) }
    let(:tax_category) { create(:tax_category) }
    let(:calculator) { Spree::Calculator::FlatRate.new }

    it "should return an empty array when tax_zone is nil" do
      allow(order).to receive_messages :tax_zone => nil
      expect(Spree::TaxRate.match(order.tax_zone)).to eq([])
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
          allow(order).to receive_messages :tax_zone => @zone
          expect(Spree::TaxRate.match(order.tax_zone)).to eq([])
        end

        it "should return the rate that matches the rate zone" do
          rate = Spree::TaxRate.create(
            :amount => 1,
            :zone => @zone,
            :tax_category => tax_category,
            :calculator => calculator
          )

          allow(order).to receive_messages :tax_zone => @zone
          expect(Spree::TaxRate.match(order.tax_zone)).to eq([rate])
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

          allow(order).to receive_messages :tax_zone => @zone
          expect(Spree::TaxRate.match(order.tax_zone)).to match_array([rate1, rate2])
        end

        context "when the tax_zone is contained within a rate zone" do
          before do
            sub_zone = create(:zone, :name => "State Zone", :zone_members => [])
            sub_zone.zone_members.create(:zoneable => create(:state, :country => country))
            allow(order).to receive_messages :tax_zone => sub_zone
            @rate = Spree::TaxRate.create(
              :amount => 1,
              :zone => @zone,
              :tax_category => tax_category,
              :calculator => calculator
            )
          end

          it "should return the rate zone" do
            expect(Spree::TaxRate.match(order.tax_zone)).to eq([@rate])
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

        subject { Spree::TaxRate.match(order.tax_zone) }

        context "when the order has the same tax zone" do
          before do
            allow(order).to receive_messages :tax_zone => @zone
          end

          context "when the tax is not a VAT" do
            it { is_expected.to eq([rate]) }
          end

          context "when the tax is a VAT" do
            let(:included_in_price) { true }
            it { is_expected.to eq([rate]) }
          end
        end

        context "when the order has a different tax zone" do
          before do
            allow(order).to receive_messages :tax_zone => create(:zone, :name => "Other Zone")
          end

          context "when the tax is a VAT" do
            let(:included_in_price) { true }
            # The rate should NOT match in this instance because:
            # The order has a different tax zone, and the price is
            # henceforth a net price and will not change.
            it 'return no tax rate' do
              expect(subject).to be_empty
            end
          end

          context "when the tax is not VAT" do
            it "returns no tax rate" do
              expect(subject).to be_empty
            end
          end
        end
      end
    end
  end

  describe ".adjust" do
    let(:order) { stub_model(Spree::Order) }
    let(:tax_category_1) { stub_model(Spree::TaxCategory) }
    let(:tax_category_2) { stub_model(Spree::TaxCategory) }
    let(:rate_1) { stub_model(Spree::TaxRate, :tax_category => tax_category_1) }
    let(:rate_2) { stub_model(Spree::TaxRate, :tax_category => tax_category_2) }

    context "with line items" do
      let(:line_item) do
        stub_model(Spree::LineItem,
          :price => 10.0,
          :quantity => 1,
          :tax_category => tax_category_1,
          :variant => stub_model(Spree::Variant)
        )
      end

      let(:line_items) { [line_item] }

      before do
        allow(Spree::TaxRate).to receive_messages :match => [rate_1, rate_2]
      end

      it "should apply adjustments for two tax rates to the order" do
        expect(rate_1).to receive(:adjust)
        expect(rate_2).not_to receive(:adjust)
        Spree::TaxRate.adjust(order, line_items)
      end
    end

    context "with shipments" do
      let(:shipments) { [stub_model(Spree::Shipment, :cost => 10.0, :tax_category => tax_category_1)] }

      before do
        allow(Spree::TaxRate).to receive_messages :match => [rate_1, rate_2]
      end

      it "should apply adjustments for two tax rates to the order" do
        expect(rate_1).to receive(:adjust)
        expect(rate_2).not_to receive(:adjust)
        Spree::TaxRate.adjust(order, shipments)
      end
    end

    context "for MOSS taxation in Europe" do
      let(:germany) { create :country, name: "Germany" }
      let(:india) { create :country, name: "India" }
      let(:france) { create :country, name: "France" }
      let(:france_zone) { create :zone_with_country, name: "France Zone" }
      let(:germany_zone) { create :zone_with_country, name: "Germany Zone", default_tax: true }
      let(:india_zone) { create :zone_with_country, name: "India" }
      let(:moss_category) { Spree::TaxCategory.create(name: "Digital Goods") }
      let(:normal_category) { Spree::TaxCategory.create(name: "Analogue Goods") }
      let(:eu_zone) { create(:zone, name: "EU") }

      let!(:german_vat) do
        Spree::TaxRate.create(
          name: "German VAT",
          amount: 0.19,
          calculator: Spree::Calculator::DefaultTax.create,
          tax_category: moss_category,
          zone: germany_zone,
          included_in_price: true
        )
      end
      let!(:french_vat) do
        Spree::TaxRate.create(
          name: "French VAT",
          amount: 0.25,
          calculator: Spree::Calculator::DefaultTax.create,
          tax_category: moss_category,
          zone: france_zone,
          included_in_price: true
        )
      end
      let!(:eu_vat) do
        Spree::TaxRate.create(
          name: "EU_VAT",
          amount: 0.19,
          calculator: Spree::Calculator::DefaultTax.create,
          tax_category: normal_category,
          zone: eu_zone,
          included_in_price: true
        )
      end

      let(:download) { create(:product, tax_category: moss_category, price: 100) }
      let(:tshirt) { create(:product, tax_category: normal_category, price: 100) }
      let(:order) { Spree::Order.create }

      before do
        germany_zone.zone_members.create(zoneable: germany)
        france_zone.zone_members.create(zoneable: france)
        india_zone.zone_members.create(zoneable: india)
        eu_zone.zone_members.create(zoneable: germany)
        eu_zone.zone_members.create(zoneable: france)
      end

      context "a download" do
        before do
          order.contents.add(download.master, 1)
        end

        it "without an adress costs 100 euros including tax" do
          Spree::TaxRate.adjust(order, order.line_items)
          order.update!
          expect(order.display_total).to eq(Spree::Money.new(100))
          expect(order.included_tax_total).to eq(15.97)
        end

        it "to germany costs 100 euros including tax" do
          allow(order).to receive(:tax_zone).and_return(germany_zone)
          Spree::TaxRate.adjust(order, order.line_items)
          order.update!
          expect(order.display_total).to eq(Spree::Money.new(100))
          expect(order.included_tax_total).to eq(15.97)
        end

        it "to france costs more including tax" do
          allow(order).to receive(:tax_zone).and_return(france_zone)
          order.update_line_item_prices!
          Spree::TaxRate.adjust(order, order.line_items)
          order.update!
          expect(order.display_total).to eq(Spree::Money.new(105.04))
          expect(order.included_tax_total).to eq(21.01)
          expect(order.additional_tax_total).to eq(0)
        end

        it "to somewhere else costs the net amount" do
          allow(order).to receive(:tax_zone).and_return(india_zone)
          order.update_line_item_prices!
          Spree::TaxRate.adjust(order, order.line_items)
          order.update!
          expect(order.included_tax_total).to eq(0)
          expect(order.included_tax_total).to eq(0)
          expect(order.display_total).to eq(Spree::Money.new(84.03))
        end
      end

      context "a t-shirt" do
        before do
          order.contents.add(tshirt.master, 1)
        end

        it "to germany costs 100 euros including tax" do
          allow(order).to receive(:tax_zone).and_return(germany_zone)
          Spree::TaxRate.adjust(order, order.line_items)
          order.update!
          expect(order.display_total).to eq(Spree::Money.new(100))
          expect(order.included_tax_total).to eq(15.97)
        end

        it "to france costs 100 euros including tax" do
          allow(order).to receive(:tax_zone).and_return(france_zone)
          order.update_line_item_prices!
          Spree::TaxRate.adjust(order, order.line_items)
          order.update!
          expect(order.display_total).to eq(Spree::Money.new(100.00))
          expect(order.included_tax_total).to eq(15.97)
          expect(order.additional_tax_total).to eq(0)
        end

        it "to somewhere else costs the net amount" do
          allow(order).to receive(:tax_zone).and_return(india_zone)
          order.update_line_item_prices!
          Spree::TaxRate.adjust(order, order.line_items)
          order.update!
          expect(order.included_tax_total).to eq(0)
          expect(order.display_total).to eq(Spree::Money.new(84.03))
        end
      end
    end
  end

  describe ".included_tax_amount_for" do
    let!(:order) { create :order_with_line_items }
    let!(:included_tax_rate) do
      create :tax_rate,
             included_in_price: true,
             tax_category: order.line_items.first.tax_category,
             zone: order.tax_zone,
             amount: 0.4
    end

    let!(:other_included_tax_rate) do
      create :tax_rate,
             included_in_price: true,
             tax_category: order.line_items.first.tax_category,
             zone: order.tax_zone,
             amount: 0.05
    end

    let!(:additional_tax_rate) do
      create :tax_rate,
             included_in_price: false,
             tax_category: order.line_items.first.tax_category,
             zone: order.tax_zone,
             amount: 0.2
    end

    let!(:included_tax_rate_from_somewhere_else) do
      create :tax_rate,
             included_in_price: true,
             tax_category: order.line_items.first.tax_category,
             zone: create(:zone_with_country),
             amount: 0.1
    end
    let(:price_options) do
      {
        tax_zone: order.tax_zone,
        tax_category: line_item.tax_category
      }
    end


    let(:line_item) { order.line_items.first }
    subject(:included_tax_amount) { Spree::TaxRate.included_tax_amount_for(price_options) }

    it 'will only get me tax amounts from tax_rates that match' do
      expect(subject).to eq(included_tax_rate.amount + other_included_tax_rate.amount)
    end
  end

  describe "#adjust" do
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
        expect(line_item.adjustments.tax.charge.count).to eq(0)
      end

      it "should not create a refund" do
        Spree::TaxRate.adjust(@order, @order.line_items)
        expect(line_item.adjustments.credit.count).to eq(0)
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
            expect(line_item.adjustments.count).to eq(2)
          end

          it "should not create a tax refund" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            expect(line_item.adjustments.credit.count).to eq(0)
          end
        end

        context "when order's zone is neither the default zone, or included in the default zone, but matches the rate's zone" do
          before do
            new_rate = Spree::TaxRate.create(
              amount: 0.2,
              included_in_price: true,
              calculator: Spree::Calculator::DefaultTax.create,
              tax_category: @category,
              zone: create(:zone_with_country)
            )
            allow(@order).to receive(:tax_zone).and_return(new_rate.zone)
          end

          it "should create an adjustment" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            expect(line_item.adjustments.charge.count).to eq(1)
          end

          it "should not create a tax refund for each tax rate" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            expect(line_item.adjustments.credit.count).to eq(0)
          end
        end

        context "when order's zone does not match default zone, is not included in the default zone, AND does not match the rate's zone" do
          before do
            @new_zone = create(:zone, :name => "New Zone", :default_tax => false)
            @new_country = create(:country, :name => "New Country")
            @new_zone.zone_members.create(:zoneable => @new_country)
            @order.ship_address = create(:address, :country => @new_country)
            @order.save
            @order.reload
          end

          it "should not create positive adjustments" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            expect(line_item.adjustments.charge.count).to eq(0)
          end

          it "should not create a tax refund for each tax rate" do
            Spree::TaxRate.adjust(@order, @order.line_items)
            expect(line_item.adjustments.credit.count).to eq(0)
          end
        end

        context "when price does not include tax" do
          before do
            allow(@order).to receive_messages :tax_zone => @zone
            [@rate1, @rate2].each do |rate|
              rate.included_in_price = false
              rate.zone = @zone
              rate.save
            end
            Spree::TaxRate.adjust(@order, @order.line_items)
          end

          it "should delete adjustments for open order when taxrate is deleted" do
            @rate1.destroy!
            @rate2.destroy!
            expect(line_item.adjustments.count).to eq(0)
          end

          it "should not delete adjustments for complete order when taxrate is deleted" do
            @order.update_column :completed_at, Time.current
            @rate1.destroy!
            @rate2.destroy!
            expect(line_item.adjustments.count).to eq(2)
          end

          it "should create an adjustment" do
            expect(line_item.adjustments.count).to eq(2)
          end

          it "should not create a tax refund" do
            expect(line_item.adjustments.credit.count).to eq(0)
          end

          describe 'tax adjustments' do
            before { Spree::TaxRate.adjust(@order, @order.line_items) }

            it "should apply adjustments when a tax zone is present" do
              expect(line_item.adjustments.count).to eq(2)
              line_item.adjustments.each do |adjustment|
                expect(adjustment.label).to eq("#{adjustment.source.tax_category.name} #{adjustment.source.amount * 100}%")
              end
            end

            describe 'when the tax zone is removed' do
              before { allow(@order).to receive_messages :tax_zone => nil }

              it 'does not apply any adjustments' do
                Spree::TaxRate.adjust(@order, @order.line_items)
                expect(line_item.adjustments.count).to eq(0)
              end
            end
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
            expect(@order.line_item_adjustments.count).to eq(2)
          end

          it "price adjustments should be accurate" do
            included_tax = @order.line_item_adjustments.sum(:amount)
            expect(@price_before_taxes + included_tax).to eq(line_item.total)
          end
        end
      end
    end
  end
end
