require 'spec_helper'

module Spree
  describe VatPriceCalculation do
    let(:test_class) do
      Class.new do
        include VatPriceCalculation
        def total
          10.0
        end
      end
    end

    describe '#gross_amount' do
      subject(:gross_amount) { test_class.new.gross_amount(amount, price_options) }

      # The catalogue is priced including this country's VAT.
      let(:home_country) { create(:country, iso: 'DE', name: 'Germany') }
      let(:destination) { create(:country, iso: 'FR', name: 'France') }
      let(:tax_category) { create(:tax_category) }
      let(:price_options) { { country: destination, tax_category: tax_category } }
      let(:amount) { 100 }

      context 'with no home country resolvable' do
        it 'leaves the price alone' do
          # Records first: a tax category needs a store, and this stubs it away.
          tax_category
          allow(Spree::Current).to receive(:market).and_return(nil)
          allow(Spree::Current).to receive(:store).and_return(nil)

          expect(TaxRate).not_to receive(:included_tax_amount_for)
          expect(gross_amount).to eq(100)
        end
      end

      context 'with a home country' do
        before { @default_store.default_market.update!(countries: [home_country]) }

        context 'and no destination given' do
          let(:price_options) { { tax_category: tax_category } }

          it 'leaves the price alone' do
            expect(TaxRate).not_to receive(:included_tax_amount_for)
            expect(gross_amount).to eq(100)
          end
        end

        context 'and the destination is the home country' do
          let(:destination) { home_country }

          it 'leaves the price alone — the VAT in it is already the right one' do
            expect(TaxRate).not_to receive(:included_tax_amount_for)
            expect(gross_amount).to eq(100)
          end
        end

        context 'and the destination is elsewhere' do
          it 'takes the home VAT out and puts the destination VAT on' do
            create(:tax_rate, country: home_country, tax_category: tax_category, amount: 0.19,
                              included_in_price: true)
            create(:tax_rate, country: destination, tax_category: tax_category, amount: 0.25,
                              included_in_price: true)

            # 100 gross at 19% is 84.03 net, which is 105.04 gross at 25%.
            expect(gross_amount).to eq(105.04)
          end

          it 'reads both rates from the tax configuration' do
            expect(TaxRate).to receive(:included_tax_amount_for).twice.and_return(0)
            gross_amount
          end
        end
      end
    end
  end
end
