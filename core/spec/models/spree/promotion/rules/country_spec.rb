require 'spec_helper'

describe Spree::Promotion::Rules::Country, type: :model do
  let(:rule) { Spree::Promotion::Rules::Country.new }
  let(:order) { create(:order) }
  let(:country) { create(:country) }
  let(:other_country) { create(:country) }

  before { allow(Spree::Country).to receive(:default) { other_country.id } }

  context 'preferred country is set' do
    before { rule.preferred_country_id = country.id }

    it 'is eligible for correct country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { country.id }
      expect(rule).to be_eligible(order)
    end

    it 'is not eligible for incorrect country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { other_country.id }
      expect(rule).not_to be_eligible(order)
    end
  end

  context 'preferred country is not set' do
    it 'is eligible for default country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { other_country.id }
      expect(rule).to be_eligible(order)
    end

    it 'is not eligible for incorrect country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { country.id }
      expect(rule).not_to be_eligible(order)
    end
  end
end
