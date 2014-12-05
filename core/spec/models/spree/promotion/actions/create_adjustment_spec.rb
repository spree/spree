require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustment, :type => :model do
  subject(:action) { Spree::Promotion::Actions::CreateAdjustment.create }
  let(:order) { create(:order_with_line_items) }

  it_behaves_like 'an adjustment source'
      
  it 'should have FlatPercentItemTotal calculator by default' do 
    expect(action.calculator).to be_an_instance_of(Spree::Calculator::FlatPercentItemTotal)
  end
    
  describe "#perform" do
    before do 
      allow(Spree::ItemAdjustments).to receive(:update)
      allow(action).to receive(:promotion).and_return(double(name: 'Promo'))
    end
    
    it 'should create an adjustment and return true' do
      expect(action.perform(order: order)).to be(true)
      expect(order.adjustments.count).to eq(1)
    end
  end
    
  describe '#compute_amount' do
    before do 
      allow(order).to receive(:promotion_accumulator).and_return(accumulator)
      allow(action.calculator).to receive(:compute).and_return(10)
    end

    context 'with accumulated total more than calculated amount' do 
      let(:accumulator) { double(total_with_promotion: 15) }
      it { expect(action.compute_amount(order)).to eq(-10) }
    end
    context 'with accumulated total less than calculated amount' do
      let(:accumulator) { double(total_with_promotion: 7) }
      it { expect(action.compute_amount(order)).to eq(-7) }      
    end
  end

end
