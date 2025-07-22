require 'spec_helper'

module Spree
  module PromotionHandler
    describe FreeShipping, type: :model do
      subject { Spree::PromotionHandler::FreeShipping.new(order) }

      let(:order) { create(:order) }
      let(:shipment) { create(:shipment, order: order) }

      let(:calculator) { Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10) }

      context 'activates in Shipment level' do
        let(:promotion) { create(:promotion, name: 'Free Shipping', stores: [order.store], kind: :automatic) }
        let!(:action) { Promotion::Actions::FreeShipping.create(promotion: promotion) }

        it 'creates the adjustment' do
          expect { subject.activate }.to change { shipment.adjustments.count }.by(1)
        end
      end

      context 'if promo has a code' do
        let(:promotion) { create(:promotion, name: 'Free Shipping', stores: [order.store], code: 'code') }
        let!(:action) { Spree::Promotion::Actions::FreeShipping.create(promotion: promotion) }

        it 'does adjust the shipment when applied to order' do
          order.promotions << promotion

          expect { subject.activate }.to change { shipment.adjustments.count }
        end

        it 'does not adjust the shipment when not applied to order' do
          expect { subject.activate }.not_to change { shipment.adjustments.count }
        end
      end

      context 'if promo has multiple codes' do
        let(:promotion) { create(:promotion, name: 'Free Shipping', stores: [order.store], multi_codes: true, number_of_codes: 1) }
        let!(:action) { Spree::Promotion::Actions::FreeShipping.create(promotion: promotion) }

        it 'does adjust the shipment when applied to order' do
          order.promotions << promotion

          expect { subject.activate }.to change { shipment.adjustments.count }
        end

        it 'does not adjust the shipment when not applied to order' do
          expect { subject.activate }.not_to change { shipment.adjustments.count }
        end
      end

      context 'if promo has a path' do
        let(:promotion) { create(:promotion, name: 'Free Shipping', stores: [order.store], kind: :automatic, path: 'path') }
        let!(:action) { Promotion::Actions::FreeShipping.create(promotion: promotion) }

        it 'does not adjust the shipment' do
          expect { subject.activate }.not_to change { shipment.adjustments.count }
        end
      end
    end
  end
end
