require 'spec_helper'

RSpec.describe 'Spree::PriceLists status workflows' do
  describe Spree::PriceLists::Activate do
    # A list needs something to apply to before it goes live; a rule is the
    # cheapest way to give one that.
    def priced_list(**attrs)
      create(:price_list, **attrs).tap { |list| create(:volume_price_rule, price_list: list, min_quantity: 2) }
    end

    it 'activates a list that is already due' do
      price_list = priced_list

      expect { described_class.call(price_list: price_list) }.to change { price_list.reload.status }.from('draft').to('active')
    end

    it 'schedules a list whose start date has not arrived' do
      price_list = priced_list(starts_at: 1.week.from_now)

      described_class.call(price_list: price_list)

      expect(price_list.reload.status).to eq('scheduled')
    end

    # No rules, no catalog, no products: it would apply to everyone and price
    # nothing. Fine as a draft being built up; refused as a live list.
    it 'refuses a list with nothing to apply to' do
      price_list = create(:price_list)

      result = described_class.call(price_list: price_list)

      expect(result).not_to be_success
      expect(price_list.reload.status).to eq('draft')
      expect(price_list.errors[:base]).to be_present
    end

    it 'accepts a list that has products even without rules' do
      price_list = create(:price_list)
      create(:price, variant: create(:variant), currency: 'USD', amount: 9, price_list: price_list)

      expect(described_class.call(price_list: price_list)).to be_success
    end

    it 'accepts a catalog-owned list with nothing else' do
      catalog = create(:catalog, store: @default_store)
      price_list = create(:price_list, store: @default_store, catalog: catalog)

      expect(described_class.call(price_list: price_list)).to be_success
    end
  end

  describe Spree::PriceLists::Deactivate do
    it 'takes the list out of effect' do
      price_list = create(:price_list, :active)

      expect { described_class.call(price_list: price_list) }.to change { price_list.reload.status }.from('active').to('inactive')
    end
  end
end
