require 'spec_helper'

module Spree
  module PromotionHandler
    describe FreeShipping do
      let(:order) { Spree::Order.create }
      let(:shipment) do 
        shipment = Spree::Shipment.new(cost: 10, order: order)
        order.shipments << shipment
        shipment
      end

      let(:promotion) { Promotion.create(name: "Free Shipping") }
      let(:calculator) { Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10) }

      subject { Spree::PromotionHandler::FreeShipping.new(order) }

      context "activates in Shipment level" do
        let!(:action) { Promotion::Actions::FreeShipping.create(promotion: promotion) }

        it "creates the adjustment" do
          expect {
            subject.activate
          }.to change { shipment.adjustments.to_a.count }.by(1)
        end
      end

      context "if promo has a code" do
        before do
          promotion.update_column(:code, "code")
        end

        it "does not adjust the shipment" do
          expect {
            subject.activate
          }.to_not change { shipment.adjustments.count }
        end
      end

      context "if promo has a path" do
        before do
          promotion.update_column(:path, "path")
        end

        it "does not adjust the shipment" do
          expect {
            subject.activate
          }.to_not change { shipment.adjustments.count }
        end
      end
    end
  end
end
