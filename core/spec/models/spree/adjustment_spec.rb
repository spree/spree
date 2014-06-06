# encoding: utf-8
#

require 'spec_helper'

describe Spree::Adjustment do

  let(:order) { mock_model(Spree::Order, update!: nil) }
  let(:default_adjustment_amount) { 5 }
  let(:updated_adjustment_amount) { 5.5 }
  let(:adjustment) { Spree::Adjustment.create(:label => "Adjustment", :amount => default_adjustment_amount) }

  context "adjustment state" do
    let(:adjustment) { create(:adjustment, state: 'open') }

    context "#closed?" do
      it "is true when adjustment state is closed" do
        adjustment.state = "closed"
        adjustment.should be_closed
      end

      it "is false when adjustment state is open" do
        adjustment.state = "open"
        adjustment.should_not be_closed
      end
    end
  end

  context "#display_amount" do
    before { adjustment.amount = 10.55 }

    context "with display_currency set to true" do
      before { Spree::Config[:display_currency] = true }

      it "shows the currency" do
        adjustment.display_amount.to_s.should == "$10.55 USD"
      end
    end

    context "with display_currency set to false" do
      before { Spree::Config[:display_currency] = false }

      it "does not include the currency" do
        adjustment.display_amount.to_s.should == "$10.55"
      end
    end

    context "with currency set to JPY" do
      context "when adjustable is set to an order" do
        before do
          order.stub(:currency) { 'JPY' }
          adjustment.adjustable = order
        end

        it "displays in JPY" do
          adjustment.display_amount.to_s.should == "¥11"
        end
      end

      context "when adjustable is nil" do
        it "displays in the default currency" do
          adjustment.display_amount.to_s.should == "$10.55"
        end
      end
    end
  end

  context '#currency' do
    it 'returns the globally configured currency' do
      adjustment.currency.should == 'USD'
    end
  end

  context '#update!' do
    context "when adjustment is closed" do
      before { adjustment.stub :closed? => true }

      it "does not update the adjustment" do
        adjustment.should_not_receive(:save)
        adjustment.update!
      end
    end

    context "when adjustment is open" do
      before { adjustment.stub :closed? => false }

      it "updates the amount" do
        adjustment.stub :adjustable => double("Adjustable")
        adjustment.stub :source => double("Source")
        adjustment.source.should_receive("compute_amount").with(adjustment.adjustable).and_return(updated_adjustment_amount)
        adjustment.should_receive(:save)
        adjustment.update!
        adjustment.amount.should == updated_adjustment_amount
      end
    end

    context "when updating the eligible attribute" do
      before(:each) do
        adjustment.stub :adjustable => double("Adjustable")
        adjustment.stub :source => double("Source", :promotion => double(Spree::Promotion, :eligible? => true))
        adjustment.stub :promotion? => true
        adjustment.source.should_receive("compute_amount").with(adjustment.adjustable)
      end

      it "skips the update if the adjustment has been already been marked ineligible" do
        adjustment.eligible = false
        adjustment.update!
        adjustment.should_not_receive(:save)
        adjustment.eligible.should == false
      end

      it "performs the update if the adjustment has been not been marked ineligible earlier" do
        adjustment.eligible = true
        adjustment.source.promotion.should_receive(:eligible?).and_return(false)
        adjustment.should_receive(:save)
        adjustment.update!
        adjustment.eligible.should == false
      end

    end

  end
end
