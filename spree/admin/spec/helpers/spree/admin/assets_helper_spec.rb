require 'spec_helper'

describe Spree::Admin::AssetsHelper do
  let(:user) { create(:admin_user) }

  before do
    allow(helper).to receive(:current_ability).and_return(Spree::Ability.new(user))
  end

  describe '#media_form_assets' do
    context 'when variant is persisted' do
      let(:variant) { create(:variant, images: [image]) }
      let(:image) { create(:image) }

      it 'returns the correct assets' do
        expect(helper.media_form_assets(variant, 'Spree::Variant')).to eq([image])
      end
    end

    context 'when product is persisted with product-level media (5.5+)' do
      let(:product) { create(:product) }
      let!(:product_image) { create(:image, viewable: product) }

      it 'returns the product-level assets via gallery_media' do
        expect(helper.media_form_assets(product, 'Spree::Product')).to include(product_image)
      end
    end

    context 'when product is persisted with legacy variant-pinned media' do
      let(:product) { create(:product) }
      let!(:master_image) { create(:image, viewable: product.master) }

      it 'falls back to variant images via gallery_media' do
        expect(helper.media_form_assets(product, 'Spree::Product')).to include(master_image)
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
