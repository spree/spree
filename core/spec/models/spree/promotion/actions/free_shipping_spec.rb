require 'spec_helper'

describe Spree::Promotion::Actions::FreeShipping, :type => :model do
  subject(:action) { Spree::Promotion::Actions::FreeShipping.new }
  let(:shipment) { create(:shipment) }

  it_behaves_like 'an adjustment source'

  describe '#perform' do
    before do 
      allow(Spree::ItemAdjustments).to receive(:update)
      allow(action).to receive(:promotion).and_return(double(name: 'Promo'))
    end

    context 'when order has shipments' do  
      let(:order) do 
        order = create(:order_with_line_items)
        order.shipments << shipment
        order.update!
        order.reload
      end

      it 'should create an adjustment for each shipment and return true' do
        expect(action.perform(order: order)).to be(true)
        expect(order.shipment_adjustments.count).to eq(2)
      end
    end

    context 'when order has no shipments' do 
      let(:order) { create(:order) }

      it 'should create no adjustments and return false' do 
        expect(action.perform(order: order)).to be(false)
        expect(order.shipment_adjustments.count).to eq(0)
      end
    end
  end

  describe '#compute_amount' do
    before { allow(shipment).to receive(:promotion_accumulator).and_return(accumulator) }

    context 'with accumulated total more than calculated amount' do 
      let(:accumulator) { double(total_with_promotion: 115) }
      it { expect(action.compute_amount(shipment)).to eq(-100) }
    end

    context 'with accumulated total less than calculated amount' do
      let(:accumulator) { double(total_with_promotion: 95) }
      it { expect(action.compute_amount(shipment)).to eq(-95) }
    end
  end
  
end
