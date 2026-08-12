require 'spec_helper'

describe Spree::PriceRules::ZoneRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:zone_price_rule, price_list: price_list) }
  let(:country) { create(:country, iso: 'DE', name: 'Germany') }
  let(:variant) { create(:variant) }

  def context_for(country_record = nil)
    Spree::Pricing::Context.new(variant: variant, currency: 'USD', country: country_record)
  end

  describe '#applicable?' do
    context 'when no country is named' do
      before { rule.preferred_country_isos = [] }

      it 'returns true for any country' do
        expect(rule.applicable?(context_for(country))).to be true
      end
    end

    context 'when a country is named' do
      before { rule.preferred_country_isos = [country.iso] }

      it 'returns true when the context country matches' do
        expect(rule.applicable?(context_for(country))).to be true
      end

      it 'returns false when the context country does not match' do
        expect(rule.applicable?(context_for(create(:country, iso: 'FR', name: 'France')))).to be false
      end

      # A context built without a country falls back to the store's, so nil only
      # reaches the guard when there is no store country either.
      it 'returns false when the context has no country at all' do
        allow(Spree::Current).to receive(:tax_country).and_return(nil)

        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD')

        expect(context.country).to be_nil
        expect(rule.applicable?(context)).to be false
      end
    end

    # Codes arrive from merchants, so case is not guaranteed either way.
    context 'when the code was entered in lowercase' do
      before { rule.preferred_country_isos = ['de'] }

      it 'returns true when the context country matches' do
        expect(rule.applicable?(context_for(country))).to be true
      end

      it 'returns false when the context country does not match' do
        expect(rule.applicable?(context_for(create(:country, iso: 'FR', name: 'France')))).to be false
      end
    end

    # There is no country table to check a code against, so an unknown one has
    # to narrow the price list to nothing rather than widen it to everywhere.
    context 'when the code is one nothing issued' do
      before { rule.preferred_country_isos = ['ZZ'] }

      it 'returns false for every country' do
        expect(rule.applicable?(context_for(country))).to be false
      end
    end
  end
  describe '#geographic?' do
    it 'is true once countries are named' do
      rule = described_class.new(price_list: price_list)
      rule.preferred_country_isos = [country.iso]

      expect(rule.geographic?).to be(true)
    end

    it 'is false while no country is named' do
      expect(described_class.new(price_list: price_list).geographic?).to be(false)
    end
  end
end
