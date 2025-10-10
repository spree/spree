require 'spec_helper'

RSpec.describe Spree::Seeds::DigitalDelivery do
  subject { described_class.call }

  describe 'ShippingMethod' do
    it 'creates a Digital Delivery shipping method' do
      expect { subject }.to change(Spree::ShippingMethod, :count).by(1)

      shipping_method = Spree::ShippingMethod.find_by(name: Spree.t('digital.digital_delivery'))
      expect(shipping_method).to be_present
      expect(shipping_method.display_on).to eq('both')
      expect(shipping_method.shipping_categories.first.name).to eq('Digital')
      expect(shipping_method.calculator).to be_a(Spree::Calculator::Shipping::DigitalDelivery)
      expect(shipping_method.zones).to match_array(Spree::Zone.all)
    end

    context 'when Digital Delivery shipping method already exists' do
      before do
        shipping_category = Spree::ShippingCategory.find_or_create_by(name: 'Digital')
        Spree::ShippingMethod.create!(
          name: Spree.t('digital.digital_delivery'),
          display_on: 'both',
          shipping_categories: [shipping_category],
          calculator: Spree::Calculator::Shipping::DigitalDelivery.create!,
          zones: Spree::Zone.all
        )
      end

      it "doesn't create a new shipping method" do
        expect { subject }.not_to change(Spree::ShippingMethod, :count)
      end
    end
  end
end
