require 'spec_helper'

describe Spree::Asset, type: :model do
  describe '#viewable' do
    it 'touches association' do
      Timecop.scale(3600) do
        product = create(:custom_product)
        asset   = Spree::Asset.create! { |a| a.viewable = product.master }

        expect do
          asset.touch
        end.to change { product.reload.updated_at }
      end
    end
  end

  describe '#acts_as_list scope' do
    it 'starts from first position for different viewables' do
      asset1 = Spree::Asset.create(viewable_type: 'Spree::Image', viewable_id: 1)
      asset2 = Spree::Asset.create(viewable_type: 'Spree::LineItem', viewable_id: 1)

      expect(asset1.position).to eq 1
      expect(asset2.position).to eq 1
    end
  end
end
