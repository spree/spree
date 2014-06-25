require 'spec_helper'

module Spree
  class Calculator
    describe PercentOnLineItem do
      let(:line_item) { double("LineItem", price: 10, quantity: 10) }

      before { subject.preferred_percent = 15 }

      it "computes based on item price and quantity" do
        expect(subject.compute(line_item)).to eq 15
      end
    end
  end
end
