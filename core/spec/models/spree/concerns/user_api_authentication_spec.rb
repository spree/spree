require 'spec_helper'

describe Spree::UserApiAuthentication do
  let(:user) { create(:user) }
  let!(:api_key) { SecureRandom.urlsafe_base64 }
  let!(:api_key2) { SecureRandom.urlsafe_base64 }

  describe '#generate_spree_api_key!' do
    before { allow(SecureRandom).to receive(:urlsafe_base64).and_return(api_key) }

    context 'spree_api_key not present' do
      before { user.spree_api_key = nil }
      it { expect { user.generate_spree_api_key! }.to change{ user.spree_api_key }.from(nil).to(api_key) }
    end

    context 'spree_api_key present' do
      before do
        user.spree_api_key = api_key2
        user.save
      end

      it { expect { user.generate_spree_api_key! }.to change{ user.spree_api_key }.from(api_key2).to(api_key) }
    end
  end

  describe '#clear_spree_api_key!' do
    before { user.spree_api_key = api_key2 }
    it { expect { user.clear_spree_api_key! }.to change{ user.spree_api_key }.from(api_key2).to(nil) }
  end

  describe '#generate_spree_api_key' do
    it { expect(user.send(:generate_spree_api_key)).not_to eq(nil) }
  end
end
