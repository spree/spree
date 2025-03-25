require 'spec_helper'

describe Spree::Admin::ProductsHelper do
  let(:user) { create(:admin_user) }

  before do
    allow(helper).to receive(:current_ability).and_return(Spree::Ability.new(user))
  end

  describe '#available_status' do
    context 'when product is active' do
      let(:product) { build(:product, status: :active) }

      it 'returns the correct status' do
        expect(available_status(product)).to eq('Active')
      end
    end

    context 'when product is draft' do
      let(:product) { build(:product, status: :draft) }

      it 'returns the correct status' do
        expect(available_status(product)).to eq('Draft')
      end
    end

    context 'when product is archived' do
      let(:product) { build(:product, status: :archived) }

      it 'returns the correct status' do
        expect(available_status(product)).to eq('Archived')
      end
    end

    xcontext 'when product is paused' do
      let(:product) { build(:product, status: :paused) }

      it 'returns the correct status' do
        expect(available_status(product)).to eq('Paused')
      end
    end

    context 'when product is deleted' do
      let(:product) { build(:product, deleted_at: Time.current) }

      it 'returns the correct status' do
        expect(available_status(product)).to eq('Deleted')
      end
    end
  end

  describe '#media_form_assets' do
    context 'when variant is persisted' do
      let(:variant) { build(:variant) }

      it 'returns the correct assets' do
        expect(helper.media_form_assets(variant)).to eq(variant.images)
      end
    end

    context 'when variant is not persisted' do
      let(:variant) { build(:variant, id: nil) }

      it 'returns an empty array' do
        expect(helper.media_form_assets(variant)).to eq([])
      end
    end

    context 'when there are session uploaded assets' do
      let(:variant) { build(:variant, id: nil) }
      let(:session_uploaded_assets) { [create(:image)] }

      before do
        allow(helper).to receive(:session_uploaded_assets).and_return(session_uploaded_assets)
      end

      it 'returns the correct assets' do
        expect(helper.media_form_assets(variant)).to eq(session_uploaded_assets)
      end
    end
  end
end
