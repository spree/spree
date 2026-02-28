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

end
