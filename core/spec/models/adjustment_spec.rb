require File.dirname(__FILE__) + '/../spec_helper'

describe Adjustment do

  context 'validations' do
    it { should have_valid_factory(:adjustment) }
  end

  context "factory_girl" do
    before do
      Order.delete_all
      @order = Factory(:order)
      @adjustment = Factory(:adjustment, :order => @order)
    end
    it 'should refer to the order that was passed to the factory' do
      @adjustment.order.id.should == @order.id
    end
  end

  let(:order) { mock_model(Order, :update! => nil) }
  let(:adjustment) { Adjustment.new }
  it "should accept a negative amount"

  context "when amount is 0" do
    before { adjustment.amount = 0 }
    it "should be applicable if mandatory?" do
      adjustment.mandatory = true
      adjustment.applicable?.should be_true
    end
    it "should not be applicable unless mandatory?" do
      adjustment.mandatory = false
      adjustment.applicable?.should be_false
    end
  end

  context "#update!" do
    context "when originator present" do
      let(:originator) { mock "originator" }
      before do
        originator.stub :update_amount => true
        adjustment.stub :originator => originator
      end
      it "should do nothing when locked" do
        adjustment.locked = true
        originator.should_not_receive(:update_adjustment)
        adjustment.update!
      end
      it "should ask the originator to update_adjustment" do
        originator.should_receive(:update_adjustment)
        adjustment.update!
      end
    end
    it "should do nothing when originator is nil" do
      adjustment.stub :originator => nil
      adjustment.should_not_receive(:amount=)
      adjustment.update!
    end
  end

  context "#save" do
    it "should call order#update!" do
      adjustment = Adjustment.new(:order => order, :amount => 10, :label => "Foo")
      order.should_receive(:update!)
      adjustment.save
    end
  end
end
