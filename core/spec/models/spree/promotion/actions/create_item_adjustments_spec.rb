require 'spec_helper'

describe Spree::Promotion::Actions::CreateItemAdjustments, :type => :model do
  subject(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create }
  let(:promotion) { double(name: 'Promo', line_item_actionable?: true) }

  before { allow(action).to receive(:promotion).and_return(promotion) }

  it 'should have PercentOnLineItem calculator by default' do 
    expect(action.calculator).to be_an_instance_of(Spree::Calculator::PercentOnLineItem)
  end

  it_behaves_like 'an adjustment source'

  describe "#perform" do
    let(:order) { create(:order) }

    before do 
      allow(Spree::ItemAdjustments).to receive(:update)
      allow(action).to receive(:promotion).and_return(double(name: 'Promo'))
      2.times { create(:line_item, order: order) }
    end

    context 'when all line_items are actionable' do 
      it 'creates adjustments on all of them and return true' do 
        expect(action.perform(order: order, promotion: promotion)).to be(true)
        expect(order.line_item_adjustments.count).to eq(2)
      end
    end

    context 'when one line_item is actionable' do    
      before { allow(promotion).to receive(:line_item_actionable?).and_return(true, false) }

      it 'creates a single adjustment and return true' do 
        expect(action.perform(order: order, promotion: promotion)).to be(true)
        expect(order.line_item_adjustments.count).to eq(1)
      end

    end
    context 'when no line_items are actionable' do 
      before { allow(promotion).to receive(:line_item_actionable?).and_return(false) }

      it 'creates no adjustments and return false' do 
        expect(action.perform(order: order, promotion: promotion)).to be(false)
        expect(order.line_item_adjustments.count).to eq(0)
      end
    end

    context 'when action has already been applied to first line_item' do
      before do 
        allow(promotion).to receive(:line_item_actionable?).and_return(true, false, true)
        action.perform(order: order, promotion: promotion)
      end

      it 'does not query if actionable or attempt to create adjustment for that line_item' do 
        expect(promotion).to receive(:line_item_actionable?).once
        expect(order.line_items[0].adjustments).to_not receive(:new)
        action.perform(order: order, promotion: promotion)
      end
    end
  end

  describe '#compute_amount' do 
    let(:line_item) { create(:line_item) }

    context 'when line_item is not actionable' do
      before { allow(promotion).to receive(:line_item_actionable?).and_return(false) } 
      it { expect(action.compute_amount(line_item)).to eq(0) }
    end

    context 'when line_item is actionable' do 

      before do 
        allow(line_item).to receive(:promotion_accumulator).and_return(accumulator)
        allow(action.calculator).to receive(:compute).and_return(10)
      end

      context 'with accumulated total more than calculated amount' do 
        let(:accumulator) { double(total_with_promotion: 15) }
        it { expect(action.compute_amount(line_item)).to eq(-10) }

      end

      context 'with accumulated total less than calculated amount' do
        let(:accumulator) { double(total_with_promotion: 7) }
        it { expect(action.compute_amount(line_item)).to eq(-7) }
      end

    end
  end

end
  

  
