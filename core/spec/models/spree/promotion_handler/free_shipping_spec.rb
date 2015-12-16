require 'spec_helper'

describe Spree::PromotionHandler::FreeShipping, type: :model do
  let(:order)     { create(:order)                  }
  let(:shipment)  { create(:shipment, order: order) }
  let(:promotion) { create(:promotion)              }

  before do
    promotion.actions << Spree::Promotion::Actions::FreeShipping
      .create!(promotion: promotion)
  end

  subject { Spree::PromotionHandler::FreeShipping.new(shipment.order) }

  context 'activates in Shipment level' do
    it 'creates the adjustment' do
      expect { subject.activate }
        .to change { shipment.adjustments.count }
        .from(0)
        .to(1)
    end
  end

  context 'if promo has a code' do
    before do
      promotion.update_attributes!(code: 'code')
    end

    it 'does adjust the shipment when applied to order' do
      order.promotions << promotion

      expect { subject.activate }
        .to change { shipment.adjustments.count }
        .from(0)
        .to(1)
    end

    it 'does not adjust the shipment when not applied to order' do
      expect { subject.activate }.to_not change { shipment.adjustments.count }
    end
  end

  context 'if promo has a path' do
    before do
      promotion.update_attributes!(path: 'path')
    end

    it 'does not adjust the shipment' do
      expect { subject.activate }.to_not change { shipment.adjustments.count }
    end
  end
end
