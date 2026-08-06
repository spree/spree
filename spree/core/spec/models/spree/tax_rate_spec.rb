require 'spec_helper'

describe Spree::TaxRate, type: :model do
  context 'match' do
    let(:order) { create(:order) }
    let(:country) { create(:country) }
    let(:tax_category) { create(:tax_category) }

    it 'returns an empty array when tax_zone is nil' do
      allow(order).to receive_messages tax_zone: nil
      expect(Spree::TaxRate.match(order.tax_zone)).to eq([])
    end

    context 'when no rate zones match the tax zone' do
      before do
        Spree::TaxRate.create(name: 'Tax Rate #1', amount: 1, zone: create(:zone))
      end

      context 'when there is no default tax zone' do
        before do
          @zone = create(:zone, name: 'Country Zone', kind: 'country', default_tax: false, zone_members: [])
          @zone.zone_members.create(zoneable: country)
        end

        it 'returns an empty array' do
          allow(order).to receive_messages tax_zone: @zone
          expect(Spree::TaxRate.match(order.tax_zone)).to eq([])
        end

        it 'returns the rate that matches the rate zone' do
          rate = Spree::TaxRate.create(
            name: 'Tax Rate #1',
            amount: 1,
            zone: @zone,
            tax_category: tax_category
          )

          allow(order).to receive_messages tax_zone: @zone
          expect(Spree::TaxRate.match(order.tax_zone)).to eq([rate])
        end

        it 'returns all rates that match the rate zone' do
          rate1 = Spree::TaxRate.create(
            name: 'Tax Rate #1',
            amount: 1,
            zone: @zone,
            tax_category: tax_category
          )

          rate2 = Spree::TaxRate.create(
            name: 'Tax Rate #2',
            amount: 2,
            zone: @zone,
            tax_category: tax_category
          )

          allow(order).to receive_messages tax_zone: @zone
          expect(Spree::TaxRate.match(order.tax_zone)).to match_array([rate1, rate2])
        end

        context 'when the tax_zone is contained within a rate zone' do
          before do
            sub_zone = create(:zone, name: 'State Zone', kind: 'state', zone_members: [])
            sub_zone.zone_members.create(zoneable: create(:state, country: country))
            allow(order).to receive_messages tax_zone: sub_zone
            @rate = Spree::TaxRate.create(
              name: 'Tax Rate #1',
              amount: 1,
              zone: @zone,
              tax_category: tax_category
            )
          end

          it 'returns the rate zone' do
            expect(Spree::TaxRate.match(order.tax_zone)).to eq([@rate])
          end
        end
      end

      context 'when there is a default tax zone' do
        subject { Spree::TaxRate.match(order.tax_zone) }

        before do
          @zone = create(:zone, name: 'Country Zone', kind: 'country', default_tax: true, zone_members: [])
          @zone.zone_members.create(zoneable: country)
        end

        let(:included_in_price) { false }
        let!(:rate) do
          Spree::TaxRate.create(name: 'Tax Rate #1',
                                amount: 1,
                                zone: @zone,
                                tax_category: tax_category,
                                included_in_price: included_in_price)
        end

        context 'when the order has the same tax zone' do
          before do
            allow(order).to receive_messages tax_zone: @zone
          end

          context 'when the tax is not a VAT' do
            it { is_expected.to eq([rate]) }
          end

          context 'when the tax is a VAT' do
            let(:included_in_price) { true }

            it { is_expected.to eq([rate]) }
          end
        end

        context 'when the order has a different tax zone' do
          before do
            allow(order).to receive_messages tax_zone: build(:zone, kind: 'country', name: 'Other Zone')
          end

          context 'when the tax is a VAT' do
            let(:included_in_price) { true }

            # The rate should NOT match in this instance because:
            # The order has a different tax zone, and the price is
            # henceforth a net price and will not change.
            it 'return no tax rate' do
              expect(subject).to be_empty
            end
          end

          context 'when the tax is not VAT' do
            it 'returns no tax rate' do
              expect(subject).to be_empty
            end
          end
        end
      end
    end
  end

  describe 'estimating through the tax provider' do
    context 'for MOSS taxation in Europe' do
      let(:germany) { create :country, name: 'Germany' }
      let(:india) { create :country, name: 'India' }
      let(:france) { create :country, name: 'France' }
      let(:france_zone) { create :zone_with_country, kind: 'country', name: 'France Zone' }
      let(:germany_zone) { create :zone_with_country, kind: 'country', name: 'Germany Zone', default_tax: true }
      let(:india_zone) { create :zone_with_country, kind: 'country', name: 'India' }
      let(:moss_category) { Spree::TaxCategory.create(name: 'Digital Goods') }
      let(:normal_category) { Spree::TaxCategory.create(name: 'Analogue Goods') }
      let(:eu_zone) { create(:zone, name: 'EU') }

      let!(:german_vat) do
        Spree::TaxRate.create(
          name: 'German VAT',
          amount: 0.19,
          tax_category: moss_category,
          zone: germany_zone,
          included_in_price: true
        )
      end
      let!(:french_vat) do
        Spree::TaxRate.create(
          name: 'French VAT',
          amount: 0.25,
          tax_category: moss_category,
          zone: france_zone,
          included_in_price: true
        )
      end
      let!(:eu_vat) do
        Spree::TaxRate.create(
          name: 'EU_VAT',
          amount: 0.19,
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

      context 'a download' do
        before do
          Spree::Orders::AddItem.call(order: order, variant: download.default_variant)
        end

        it 'without an address costs 100 euros including tax' do
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(100))
          expect(order.included_tax_total).to eq(15.97)
        end

        it 'to germany costs 100 euros including tax' do
          allow(order).to receive(:tax_zone).and_return(germany_zone)
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(100))
          expect(order.included_tax_total).to eq(15.97)
        end

        it 'to france costs more including tax' do
          allow(order).to receive(:tax_zone).and_return(france_zone)
          order.update_line_item_prices!
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(105.04))
          expect(order.included_tax_total).to eq(21.01)
          expect(order.additional_tax_total).to eq(0)
        end

        it 'to somewhere else costs the net amount' do
          allow(order).to receive(:tax_zone).and_return(india_zone)
          order.update_line_item_prices!
          order.recalculate_totals!
          expect(order.included_tax_total).to eq(0)
          expect(order.display_total).to eq(Spree::Money.new(84.03))
        end
      end

      context 'a t-shirt' do
        it 'to germany costs 100 euros including tax' do
          allow(order).to receive(:tax_zone).and_return(germany_zone)
          Spree::Orders::AddItem.call(order: order, variant: tshirt.default_variant)
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(100))
          expect(order.included_tax_total).to eq(15.97)
        end

        it 'to france costs 100 euros including tax' do
          allow(order).to receive(:tax_zone).and_return(france_zone)
          Spree::Orders::AddItem.call(order: order, variant: tshirt.default_variant)
          order.update_line_item_prices!
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(100.00))
          expect(order.included_tax_total).to eq(15.97)
          expect(order.additional_tax_total).to eq(0)
        end

        it 'to somewhere else costs the net amount' do
          allow(order).to receive(:tax_zone).and_return(india_zone)
          Spree::Orders::AddItem.call(order: order, variant: tshirt.default_variant)
          order.update_line_item_prices!
          order.recalculate_totals!
          expect(order.included_tax_total).to eq(0)
          expect(order.display_total).to eq(Spree::Money.new(84.03))
        end
      end
    end

    describe 'tax line lifecycle around rate deletion' do
      let!(:order) { create(:order) }
      let(:zone) do
        create(:zone, name: 'Country Zone', kind: 'country', default_tax: true, zone_members: []).tap do |zone|
          zone.zone_members.create(zoneable: create(:country))
        end
      end
      let(:category) { Spree::TaxCategory.create(name: 'Taxable Foo') }
      let!(:rate) do
        Spree::TaxRate.create(name: 'Tax Rate #1', amount: 0.1, tax_category: category, zone: zone)
      end
      let(:taxable) { create(:product, tax_category: category) }
      let!(:line_item) { Spree::Orders::AddItem.call(order: order, variant: taxable.default_variant).value }

      before do
        allow_any_instance_of(Spree::Order).to receive(:tax_zone).and_return(zone)
        Spree.tax_provider.estimate(order)
      end

      it 'keeps the tax line with snapshots when the rate is deleted' do
        expect(order.tax_lines.reload.count).to eq(1)

        rate.destroy!
        tax_line = order.tax_lines.reload.sole
        expect(tax_line.tax_rate_id).to be_nil
        expect(tax_line.rate).to eq(0.1)
      end

      it 'drops the line on the next estimate after the rate is gone' do
        rate.destroy!
        Spree.tax_provider.estimate(order)
        expect(order.tax_lines.reload).to be_empty
      end
    end
  end

  describe '.included_tax_amount_for' do
    subject(:included_tax_amount) { Spree::TaxRate.included_tax_amount_for(price_options) }

    let!(:order) { create :order_with_line_items }
    let!(:default_tax_zone) do
      create(:zone, default_tax: true, kind: 'country').tap do |zone|
        zone.zone_members.create!(zoneable: order.tax_address.country)
      end
    end
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

    it 'will only get me tax amounts from tax_rates that match' do
      expect(subject).to eq(included_tax_rate.amount + other_included_tax_rate.amount)
    end
  end

  describe '#adjustment_label' do
    it 'returns the name and amount for the tax rate' do
      tax_rate = Spree::TaxRate.new(name: 'Sales Tax', amount: 0.1)
      expect(tax_rate.adjustment_label).to eq('Sales Tax 10%')
    end
  end

  describe '#amount_for_label' do
    it 'returns an empty string when the amount is 0' do
      tax_rate = Spree::TaxRate.new(amount: 0)
      expect(tax_rate.send(:amount_for_label)).to eq('')
    end

    it 'returns a string with the percentage when the amount is not 0' do
      tax_rate = Spree::TaxRate.new(amount: 0.1)
      expect(tax_rate.send(:amount_for_label)).to eq(' 10%')
    end
  end

  describe 'percentage conversion' do
    describe '#amount_percentage' do
      it 'converts decimal amount to percentage' do
        tax_rate = build(:tax_rate, amount: 0.0825)
        expect(tax_rate.amount_percentage).to eq(8.25)
      end

      it 'returns nil when amount is nil' do
        tax_rate = build(:tax_rate, amount: nil)
        expect(tax_rate.amount_percentage).to be_nil
      end

      it 'handles zero amount' do
        tax_rate = build(:tax_rate, amount: 0.0)
        expect(tax_rate.amount_percentage).to eq(0.0)
      end

      it 'rounds to 2 decimal places' do
        tax_rate = build(:tax_rate, amount: 0.12345)
        expect(tax_rate.amount_percentage).to eq(12.35)
      end
    end

    describe '#amount_percentage=' do
      it 'converts percentage to decimal amount' do
        tax_rate = build(:tax_rate)
        tax_rate.amount_percentage = 8.25
        expect(tax_rate.amount).to eq(0.0825)
      end

      it 'sets amount to nil when percentage is nil' do
        tax_rate = build(:tax_rate)
        tax_rate.amount_percentage = nil
        expect(tax_rate.amount).to be_nil
      end

      it 'sets amount to nil when percentage is empty string' do
        tax_rate = build(:tax_rate)
        tax_rate.amount_percentage = ''
        expect(tax_rate.amount).to be_nil
      end

      it 'handles zero percentage' do
        tax_rate = build(:tax_rate)
        tax_rate.amount_percentage = 0
        expect(tax_rate.amount).to eq(0.0)
      end

      it 'handles string percentage values' do
        tax_rate = build(:tax_rate)
        tax_rate.amount_percentage = '5.5'
        expect(tax_rate.amount).to eq(0.055)
      end
    end
  end

  describe 'store binding' do
    it 'falls back to the current store' do
      expect(create(:tax_rate).store).to eq(@default_store)
    end

    it 'keeps an explicitly assigned store' do
      other_store = create(:store)
      expect(create(:tax_rate, store: other_store).store).to eq(other_store)
    end

    it 'only returns rates of the given store' do
      other_store = create(:store)
      own_rate = create(:tax_rate)
      create(:tax_rate, store: other_store)

      expect(Spree::TaxRate.for_store(@default_store)).to eq([own_rate])
    end
  end
end
