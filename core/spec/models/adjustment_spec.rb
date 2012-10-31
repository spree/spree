require 'spec_helper'

describe Spree::Adjustment do

  let(:order) { mock_model(Spree::Order, :update! => nil) }
  let(:adjustment) { Spree::Adjustment.new }

  context "#update!" do
    context "when originator present" do
      let(:originator) { mock("originator", :update_adjustment => nil) }
      before do
        originator.stub :update_amount => true
        adjustment.stub :originator => originator
      end
      it "should do nothing when locked" do
        adjustment.locked = true
        originator.should_not_receive(:update_adjustment)
        adjustment.update!
      end
      it "should set the eligibility" do
        adjustment.should_receive(:set_eligibility)
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

  context "#eligible? after #set_eligibility" do
    context "when amount is 0" do
      before { adjustment.amount = 0 }
      it "should be eligible if mandatory?" do
        adjustment.mandatory = true
        adjustment.set_eligibility
        adjustment.should be_eligible
      end
      it "should not be eligible unless mandatory?" do
        adjustment.mandatory = false
        adjustment.set_eligibility
        adjustment.should_not be_eligible
      end
    end
    context "when amount is greater than 0" do
      before { adjustment.amount = 25.00 }
      it "should be eligible if mandatory?" do
        adjustment.mandatory = true
        adjustment.set_eligibility
        adjustment.should be_eligible
      end
      it "should be eligible if not mandatory and eligible for the originator" do
        adjustment.mandatory = false
        adjustment.stub(:eligible_for_originator? => true)
        adjustment.set_eligibility
        adjustment.should be_eligible
      end
      it "should not be eligible if not mandatory not eligible for the originator" do
        adjustment.mandatory = false
        adjustment.stub(:eligible_for_originator? => false)
        adjustment.set_eligibility
        adjustment.should_not be_eligible
      end
    end
  end

  context "#save" do
    it "should call order#update!" do
      adjustment = Spree::Adjustment.new({:adjustable => order, :amount => 10, :label => "Foo"}, :without_protection => true)
      order.should_receive(:update!)
      adjustment.save
    end
  end


  context "#eligible_for_originator?" do
    context "with no originator" do
      specify { adjustment.should be_eligible_for_originator }
    end
    context "with originator that doesn't have 'eligible?'" do
      before { adjustment.originator = mock_model(Spree::TaxRate) }
      specify { adjustment.should be_eligible_for_originator }
    end
    context "with originator that has 'eligible?'" do
      let(:originator) { Spree::TaxRate.new }
      before { adjustment.originator = originator }
      context "and originator is eligible for order" do
        before { originator.stub(:eligible? => true) }
        specify { adjustment.should be_eligible_for_originator }
      end
      context "and originator is not eligible for order" do
        before { originator.stub(:eligible? => false) }
        specify { adjustment.should_not be_eligible_for_originator }
      end
    end
  end

  context "#display_amount" do
    before { adjustment.amount = 10.55 }

    context "with display_currency set to true" do
      before { Spree::Config[:display_currency] = true }

      it "shows the currency" do
        adjustment.display_amount.should == "$10.55 USD"
      end
    end

    context "with display_currency set to false" do
      before { Spree::Config[:display_currency] = false }

      it "does not include the currency" do
        adjustment.display_amount.should == "$10.55"
      end
    end
  end
end
