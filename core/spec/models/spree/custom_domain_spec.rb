require 'spec_helper'

RSpec.describe Spree::CustomDomain, type: :model do
  let!(:store) { Spree::Store.default }

  describe 'Validations' do
    describe '#sanitize_url' do
      let(:custom_domain) { build(:custom_domain, url: 'https://shop.custom.domain ') }

      it 'removes https:// and http:// from the url' do
        custom_domain.valid?
        expect(custom_domain.url).to eq('shop.custom.domain')
      end
    end

    describe '#url_is_valid' do
      it 'is valid with valid url' do
        expect(build(:custom_domain, url: 'shop.custom.domain')).to be_valid
      end

      it 'is invalid with wrong number of parts' do
        expect(build(:custom_domain, url: 'com')).not_to be_valid
      end
    end
  end
end
