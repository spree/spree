require 'spec_helper'

describe Spree::PriceRules::ZoneRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:zone_price_rule, price_list: price_list) }
  let(:country) { create(:country) }
  let(:variant) { create(:variant) }

  def context_for(country_record = nil)
    Spree::Pricing::Context.new(variant: variant, currency: 'USD', country: country_record)
  end

  describe '#applicable?' do
    context 'when country_ids preference is empty' do
      before { rule.preferred_country_ids = [] }

      it 'returns true for any country' do
        expect(rule.applicable?(context_for(country))).to be true
      end
    end

    context 'when country_ids preference is set' do
      before { rule.preferred_country_ids = [country.id] }

      it 'returns true when the context country matches' do
        expect(rule.applicable?(context_for(country))).to be true
      end

      it 'returns false when the context country does not match' do
        expect(rule.applicable?(context_for(create(:country)))).to be false
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

    # UUID primary keys mean an id may arrive as either type.
    context 'when country_ids preference contains strings' do
      before { rule.preferred_country_ids = [country.id.to_s] }

      it 'returns true when the context country matches' do
        expect(rule.applicable?(context_for(country))).to be true
      end

      it 'returns false when the context country does not match' do
        expect(rule.applicable?(context_for(create(:country)))).to be false
      end
    end
  end
  describe '#geographic?' do
    it 'is true' do
      # A list narrowed by geography states its prices for that geography, so
      # they are charged as entered rather than restated for the buyer's VAT.
      expect(described_class.new.geographic?).to be(true)
    end
  end
end
