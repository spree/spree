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

  describe '#sorted_product_properties' do
    let(:product) { create(:product) }

    context 'when the product has product properties' do
      let!(:product_property1) { create(:product_property, product: product, property: create(:property, position: 2)) }
      let!(:product_property2) { create(:product_property, product: product, property: create(:property, position: 1)) }

      it 'returns the product properties sorted by position' do
        expect(sorted_product_properties(product)).to eq([product_property2, product_property1])
      end
    end

    context 'when the product has no product properties' do
      it 'returns an empty array' do
        expect(sorted_product_properties(product)).to eq([])
      end
    end
  end
end
