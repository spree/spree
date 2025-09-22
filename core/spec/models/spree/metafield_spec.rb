require 'spec_helper'

RSpec.describe Spree::Metafield, type: :model do
  let(:product) { create(:product) }

  describe 'Scopes' do
    let!(:public_metafield) { create(:metafield, resource: product, visibility: 'public') }
    let!(:private_metafield) { create(:metafield, resource: product, visibility: 'private') }

    describe '.public_metafields' do
      it 'returns only public metafields' do
        expect(Spree::Metafield.public_metafields).to include(public_metafield)
        expect(Spree::Metafield.public_metafields).not_to include(private_metafield)
      end
    end

    describe '.private_metafields' do
      it 'returns only private metafields' do
        expect(Spree::Metafield.private_metafields).to include(private_metafield)
        expect(Spree::Metafield.private_metafields).not_to include(public_metafield)
      end
    end
  end
end
