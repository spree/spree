require 'spec_helper'

describe Spree::Addresses::Find do
  let!(:user) { create(:user) }
  let!(:address1) { create(:address, user: user) }
  let!(:address2) { create(:address, user: user) }
  let!(:address3) { create(:address, user: user, quick_checkout: true) }
  let!(:address4) { create(:address, user: user, quick_checkout: true) }

  describe '#execute' do
    let(:scope) { Spree::Address.where(user: user) }

    context 'without any filter parameters' do
      let(:params) { {} }

      it 'returns all addresses without filtering' do
        result = described_class.new(
          scope: scope,
          params: params
        ).execute

        expect(result).to include(address1)
        expect(result).to include(address2)
        expect(result).to include(address3)
        expect(result).to include(address4)
      end
    end

    context 'with exclude_quick_checkout filter set to truthy value' do
      let(:params) { { filter: { exclude_quick_checkout: '1' } } }

      it 'returns only non-quick-checkout addresses' do
        result = described_class.new(
          scope: scope,
          params: params
        ).execute

        expect(result).to include(address1)
        expect(result).to include(address2)
        expect(result).not_to include(address3)
        expect(result).not_to include(address4)
      end
    end

    context 'with exclude_quick_checkout filter set to falsey value' do
      let(:params) { { filter: { exclude_quick_checkout: nil } } }

      it 'returns all addresses without filtering' do
        result = described_class.new(
          scope: scope,
          params: params
        ).execute

        expect(result).to include(address1)
        expect(result).to include(address2)
        expect(result).to include(address3)
        expect(result).to include(address4)
      end
    end
  end
end
