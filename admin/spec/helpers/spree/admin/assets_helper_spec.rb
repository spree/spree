require 'spec_helper'

describe Spree::Admin::AssetsHelper do
  let(:user) { create(:admin_user) }

  before do
    allow(helper).to receive(:current_ability).and_return(Spree::Ability.new(user))
  end

  describe '#media_form_assets' do
    context 'when variant is persisted' do
      let(:variant) { build(:variant) }

      it 'returns the correct assets' do
        expect(helper.media_form_assets(variant, 'Spree::Variant')).to eq(variant.images)
      end
    end

    context 'when variant is not persisted' do
      let(:variant) { build(:variant, id: nil) }

      it 'returns an empty array' do
        expect(helper.media_form_assets(variant, 'Spree::Variant')).to eq([])
      end
    end

    context 'when there are session uploaded assets' do
      let(:variant) { build(:variant, id: nil) }
      let(:session_uploaded_assets) { [create(:asset)] }

      before do
        allow(helper).to receive(:session_uploaded_assets).and_return(session_uploaded_assets)
      end

      it 'returns the correct assets' do
        expect(helper.media_form_assets(variant, 'Spree::Variant')).to eq(session_uploaded_assets)
      end
    end
  end
end
