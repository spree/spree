require 'spec_helper'

RSpec.describe 'Spree::PriceLists status workflows' do
  describe Spree::PriceLists::Activate do
    it 'activates a list that is already due' do
      price_list = create(:price_list)

      expect { described_class.call(price_list: price_list) }.to change { price_list.reload.status }.from('draft').to('active')
    end

    it 'schedules a list whose start date has not arrived' do
      price_list = create(:price_list, starts_at: 1.week.from_now)

      described_class.call(price_list: price_list)

      expect(price_list.reload.status).to eq('scheduled')
    end
  end

  describe Spree::PriceLists::Deactivate do
    it 'takes the list out of effect' do
      price_list = create(:price_list, :active)

      expect { described_class.call(price_list: price_list) }.to change { price_list.reload.status }.from('active').to('inactive')
    end
  end
end
