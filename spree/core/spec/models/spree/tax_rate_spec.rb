require 'spec_helper'

describe Spree::TaxRate, type: :model do
  describe 'jurisdiction matching' do
    let(:germany) { create(:country, iso: 'DE', name: 'Germany') }
    let(:berlin) { create(:state, country: germany, abbr: 'BE', name: 'Berlin') }
    let(:france) { create(:country, iso: 'FR', name: 'France') }
    let(:tax_category) { create(:tax_category) }
    # A name that resolves to no subdivision: 'Berlin' would be promoted to
    # its ISO code (BE) now that Germany carries the gem's subdivision list,
    # and these examples are about an address whose jurisdiction is unknown.
    let(:german_address) { create(:address, country: germany, state: nil, state_name: 'Somewhere') }

    it 'falls back to rates that tax everywhere when the jurisdiction is unknown' do
      worldwide = create(:tax_rate, :worldwide, tax_category: tax_category)
      create(:tax_rate, country_code: germany&.iso, tax_category: tax_category)

      # A rate naming no country taxes everywhere, so it still applies when we
      # cannot say where the sale is — a country-specific one does not.
      expect(described_class.for_jurisdiction(nil)).to eq([worldwide])
    end

    it 'reads a jurisdiction off an address, or takes the pair directly' do
      rate = create(:tax_rate, country_code: germany&.iso, tax_category: tax_category)

      expect(described_class.for_address(german_address)).to eq([rate])
      expect(described_class.for_jurisdiction(germany.iso)).to eq([rate])
    end

    it 'matches a rate for the address country' do
      rate = create(:tax_rate, country_code: germany&.iso, tax_category: tax_category)
      create(:tax_rate, country_code: france&.iso, tax_category: tax_category)

      expect(described_class.for_address(german_address)).to eq([rate])
    end

    it 'matches every rate configured for that country' do
      standard = create(:tax_rate, country_code: germany&.iso, amount: 0.19, tax_category: tax_category)
      reduced = create(:tax_rate, country_code: germany&.iso, amount: 0.07, tax_category: create(:tax_category))

      expect(described_class.for_address(german_address)).to match_array([standard, reduced])
    end

    it 'matches a rate that taxes every country' do
      worldwide = create(:tax_rate, :worldwide, tax_category: tax_category)

      expect(described_class.for_address(german_address)).to eq([worldwide])
    end

    context 'with state-level rates' do
      let(:berlin_address) { create(:address, country: germany, state: berlin) }

      it 'matches the state rate alongside the country rate' do
        country_rate = create(:tax_rate, country_code: germany&.iso, tax_category: tax_category)
        state_rate = create(:tax_rate, country_code: germany&.iso, state_code: berlin&.abbr, tax_category: create(:tax_category))

        expect(described_class.for_address(berlin_address)).to match_array([country_rate, state_rate])
      end

      it 'does not match another state rate' do
        hamburg = create(:state, country: germany, abbr: 'HH', name: 'Hamburg')
        create(:tax_rate, country_code: germany&.iso, state_code: hamburg&.abbr, tax_category: tax_category)

        expect(described_class.for_address(berlin_address)).to be_empty
      end

      it 'does not match a state rate for an address with no state' do
        create(:tax_rate, country_code: germany&.iso, state_code: berlin&.abbr, tax_category: tax_category)

        expect(described_class.for_address(german_address)).to be_empty
      end
    end

    # Writes reject a state code from another country; a stored one — left by
    # registry drift — simply never matches an address, which is what the
    # mismatch always meant.
    it 'never matches when the state code belongs to another country' do
      rate = create(:tax_rate, country_code: 'FR', tax_category: tax_category)
      rate.update_columns(state_code: berlin&.abbr)

      expect(described_class.for_address(german_address)).to be_empty
    end

    it 'matches regardless of the case a code was entered in' do
      rate = create(:tax_rate, country_code: 'de', tax_category: tax_category)

      expect(rate.country_code).to eq('DE')
      expect(described_class.for_address(german_address)).to eq([rate])
    end
  end

  describe 'estimating through the tax provider' do
    # The EU one-stop-shop case: a catalogue priced gross in the store's own
    # country, restated for a customer taxed somewhere else.
    context 'for MOSS taxation in Europe' do
      let(:germany) { create(:country, iso: 'DE', name: 'Germany') }
      let(:france) { create(:country, iso: 'FR', name: 'France') }
      let(:india) { create(:country, iso: 'IN', name: 'India') }

      let(:moss_category) { create(:tax_category, name: 'Digital Goods') }
      let(:normal_category) { create(:tax_category, name: 'Analogue Goods') }

      let!(:german_vat) do
        create(:tax_rate, name: 'German VAT', amount: 0.19, tax_category: moss_category,
                          country_code: germany&.iso, included_in_price: true)
      end
      let!(:french_vat) do
        create(:tax_rate, name: 'French VAT', amount: 0.25, tax_category: moss_category,
                          country_code: france&.iso, included_in_price: true)
      end
      # Physical goods are taxed where they ship from, so both EU countries
      # carry the same rate — one row each, a zone spanning both being gone.
      let!(:german_goods_vat) do
        create(:tax_rate, name: 'EU VAT (DE)', amount: 0.19, tax_category: normal_category,
                          country_code: germany&.iso, included_in_price: true)
      end
      let!(:french_goods_vat) do
        create(:tax_rate, name: 'EU VAT (FR)', amount: 0.19, tax_category: normal_category,
                          country_code: france&.iso, included_in_price: true)
      end

      let(:download) { create(:product, tax_category: moss_category, price: 100) }
      let(:tshirt) { create(:product, tax_category: normal_category, price: 100) }
      let(:order) { create(:order, ship_address: nil, bill_address: nil) }

      # Prices are quoted including German VAT — the market being browsed is
      # Germany, which is where the store's own country comes from.
      before { @default_store.default_market.update!(countries: [germany]) }

      ZIPCODES = { 'DE' => '10115', 'FR' => '75001', 'IN' => '110001' }.freeze

      # India requires a subdivision, so it gets a real one; the EU countries
      # don't, and keep free text there.
      def ship_to(country)
        state = country.states_required? ? country.states.first : nil
        order.update!(
          ship_address: create(:address, country: country, state: state,
                                         state_name: state ? nil : 'Somewhere',
                                         zipcode: ZIPCODES.fetch(country.iso))
        )
        order.update_line_item_prices!
      end

      context 'a download' do
        before { Spree::Orders::AddItem.call(order: order, variant: download.default_variant) }

        it 'without an address costs 100 euros including tax' do
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(100))
          expect(order.included_tax_total).to eq(15.97)
        end

        it 'to germany costs 100 euros including tax' do
          ship_to(germany)
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(100))
          expect(order.included_tax_total).to eq(15.97)
        end

        it 'to france costs more including tax' do
          ship_to(france)
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(105.04))
          expect(order.included_tax_total).to eq(21.01)
          expect(order.additional_tax_total).to eq(0)
        end

        it 'to somewhere else costs the net amount' do
          ship_to(india)
          order.recalculate_totals!
          expect(order.included_tax_total).to eq(0)
          expect(order.display_total).to eq(Spree::Money.new(84.03))
        end
      end

      context 'a t-shirt' do
        before { Spree::Orders::AddItem.call(order: order, variant: tshirt.default_variant) }

        it 'to germany costs 100 euros including tax' do
          ship_to(germany)
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(100))
          expect(order.included_tax_total).to eq(15.97)
        end

        it 'to france costs 100 euros including tax' do
          ship_to(france)
          order.recalculate_totals!
          expect(order.display_total).to eq(Spree::Money.new(100.00))
          expect(order.included_tax_total).to eq(15.97)
          expect(order.additional_tax_total).to eq(0)
        end

        it 'to somewhere else costs the net amount' do
          ship_to(india)
          order.recalculate_totals!
          expect(order.included_tax_total).to eq(0)
          expect(order.display_total).to eq(Spree::Money.new(84.03))
        end
      end
    end

    describe 'tax line lifecycle around rate deletion' do
      let(:country) { Spree::Country.by_iso('US') }
      let!(:order) { create(:order, ship_address: create(:address, country: country)) }
      let(:category) { create(:tax_category, name: 'Taxable Foo') }
      let!(:rate) do
        create(:tax_rate, name: 'Tax Rate #1', amount: 0.1, tax_category: category, country_code: country&.iso)
      end
      let(:taxable) { create(:product, tax_category: category) }
      let!(:line_item) { Spree::Orders::AddItem.call(order: order, variant: taxable.default_variant).value }

      before { order.tax_provider.estimate(order) }

      it 'keeps the tax line with snapshots when the rate is deleted' do
        expect(order.tax_lines.reload.count).to eq(1)

        rate.destroy!
        tax_line = order.tax_lines.reload.sole
        expect(tax_line.tax_rate_id).to be_nil
        expect(tax_line.rate).to eq(0.1)
      end

      it 'drops the line on the next estimate after the rate is gone' do
        rate.destroy!
        order.tax_provider.estimate(order)
        expect(order.tax_lines.reload).to be_empty
      end
    end
  end

  describe '.included_tax_amount_for' do
    subject(:included_tax_amount) { Spree::TaxRate.included_tax_amount_for(price_options) }

    let!(:order) { create :order_with_line_items }
    let(:line_item) { order.line_items.first }
    let(:country) { order.tax_address.country }

    let!(:included_tax_rate) do
      create(:tax_rate, included_in_price: true, tax_category: line_item.tax_category,
                        country_code: country&.iso, amount: 0.4)
    end
    let!(:other_included_tax_rate) do
      create(:tax_rate, included_in_price: true, tax_category: line_item.tax_category,
                        country_code: country&.iso, amount: 0.05)
    end
    # Additional tax is added to the price rather than sitting inside it.
    let!(:additional_tax_rate) do
      create(:tax_rate, included_in_price: false, tax_category: line_item.tax_category,
                        country_code: country&.iso, amount: 0.2)
    end
    let!(:included_tax_rate_from_somewhere_else) do
      create(:tax_rate, included_in_price: true, tax_category: line_item.tax_category,
                        country_code: create(:country, iso: 'JP', name: 'Japan')&.iso, amount: 0.1)
    end

    let(:price_options) { { country: country, tax_category: line_item.tax_category } }

    it 'sums only the included rates of that jurisdiction' do
      expect(included_tax_amount).to eq(0.45)
    end

    it 'accepts an address instead of a country' do
      expect(described_class.included_tax_amount_for(address: order.tax_address,
                                                    tax_category: line_item.tax_category)).to eq(0.45)
    end

    it 'is zero without a jurisdiction' do
      expect(described_class.included_tax_amount_for(tax_category: line_item.tax_category)).to eq(0)
    end

    it 'is zero without a tax category' do
      expect(described_class.included_tax_amount_for(country: country)).to eq(0)
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
