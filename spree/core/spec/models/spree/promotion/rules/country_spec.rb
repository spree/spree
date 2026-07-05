require 'spec_helper'

describe Spree::Promotion::Rules::Country, type: :model do
  let!(:store) { create(:store, default_country: other_country) }
  let(:rule) { described_class.new }
  let(:order) { create(:order, store: store) }
  let(:country) { create(:country) }
  let(:other_country) { create(:country) }

  context 'preferred country_id is set' do
    before { rule.preferred_country_id = country.id }

    it 'is eligible for correct country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { country.id }
      allow(order).to receive_message_chain(:ship_address, :country_iso) { country.iso }

      expect(rule).to be_eligible(order)
    end

    it 'is not eligible for incorrect country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { other_country.id }
      allow(order).to receive_message_chain(:ship_address, :country_iso) { other_country.iso }

      expect(rule).not_to be_eligible(order)

      expect(rule.eligibility_errors.count).to eq(1)
      expect(rule.eligibility_errors.to_hash[:base]).to eq([Spree.t('eligibility_errors.messages.wrong_country')])
    end
  end

  context 'preferred country_iso is set' do
    before { rule.preferred_country_iso = country.iso }

    it 'is eligible for correct country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { country.id }
      allow(order).to receive_message_chain(:ship_address, :country_iso) { country.iso }

      expect(rule).to be_eligible(order)
      expect(rule.eligibility_errors).to be_empty
    end

    it 'is not eligible for incorrect country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { other_country.id }
      allow(order).to receive_message_chain(:ship_address, :country_iso) { other_country.iso }

      expect(rule).not_to be_eligible(order)

      expect(rule.eligibility_errors.count).to eq(1)
      expect(rule.eligibility_errors.to_hash[:base]).to eq([Spree.t('eligibility_errors.messages.wrong_country')])
    end
  end

  context 'preferred country is not set' do
    it 'is eligible for default country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { other_country.id }
      allow(order).to receive_message_chain(:ship_address, :country_iso) { other_country.iso }

      expect(rule).to be_eligible(order)
    end

    it 'is not eligible for incorrect country' do
      allow(order).to receive_message_chain(:ship_address, :country_id) { country.id }
      allow(order).to receive_message_chain(:ship_address, :country_iso) { country.iso }

      expect(rule).not_to be_eligible(order)

      expect(rule.eligibility_errors.count).to eq(1)
      expect(rule.eligibility_errors.to_hash[:base]).to eq([Spree.t('eligibility_errors.messages.wrong_country')])
    end
  end
end
