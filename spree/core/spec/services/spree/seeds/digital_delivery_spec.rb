require 'spec_helper'

RSpec.describe Spree::Seeds::DigitalDelivery do
  subject { described_class.call }

  describe 'DeliveryMethod' do
    it 'creates a Digital Delivery delivery method' do
      expect { subject }.to change(Spree::DeliveryMethod, :count).by(1)

      delivery_method = Spree::DeliveryMethod.find_by(name: Spree.t('digital.digital_delivery'))
      expect(delivery_method).to be_present
      expect(delivery_method.storefront_visible).to be true
      expect(delivery_method.fulfillment_type).to eq('digital')
      expect(delivery_method).to be_digital
      expect(delivery_method.calculator).to be_a(Spree::Calculator::Shipping::DigitalDelivery)
    end

    context 'when Digital Delivery delivery method already exists' do
      before do
        Spree::DeliveryMethod.create!(
          name: Spree.t('digital.digital_delivery'),
          storefront_visible: true,
          fulfillment_type: 'digital',
          calculator: Spree::Calculator::Shipping::DigitalDelivery.create!
        )
      end

      it "doesn't create a new delivery method" do
        expect { subject }.not_to change(Spree::DeliveryMethod, :count)
      end
    end
  end
end
