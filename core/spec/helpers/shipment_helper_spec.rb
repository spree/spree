require 'spec_helper'

module Spree
  describe ShipmentHelper, type: :helper do
    let(:shipment) { create(:shipment, external_tracking_url: tracking_url, tracking: tracking) }
    let(:tracking) { 'tracking' }
    let(:tracking_url) { 'https://example.com' }
    let(:options) { {} }

    describe '#shipment_tracking_link_to' do
      subject(:shipment_tracking_link_to) { helper.shipment_tracking_link_to(shipment, options) }

      context 'with tracking and tracking_url' do
        it 'creates link with tracking as a name' do
          expect(shipment_tracking_link_to).to eq('<a href="https://example.com">tracking</a>')
        end
      end

      context 'with tracking_url only' do
        let(:tracking) { nil }
        let(:tracking_url) { 'https://example.com' }
        
        it 'creates a link with tracking_url as a name' do
          expect(shipment_tracking_link_to).to eq('<a href="https://example.com">https://example.com</a>')
        end
      end

      context 'with options' do
        let(:options) { { data: { foo: 'bar'  } } }

        it 'sets options for link' do
          expect(shipment_tracking_link_to).to include(' data-foo="bar"')
        end
      end
    end
  end
end