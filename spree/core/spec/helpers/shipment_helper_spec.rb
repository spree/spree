require 'spec_helper'

module Spree
  describe ShipmentHelper, type: :helper do
    let(:shipment) { create(:shipment, tracking: tracking) }
    let(:tracking) { 'tracking' }

    before do
      allow(shipment).to receive(:tracking_url).and_return(tracking_url)
    end

    describe '#shipment_tracking_link_to' do
      subject(:shipment_tracking_link_to) { helper.shipment_tracking_link_to(**params) }

      let(:params) do
        {
          shipment: shipment,
        }
      end

      let(:tracking_url) { 'https://example.com?tracking=Abc' }

      context 'with tracking and tracking_url' do
        it 'creates link with tracking as a name' do
          expect(shipment_tracking_link_to).to eq('<a href="https://example.com?tracking=Abc">tracking</a>')
        end
      end

      context 'with name passed in params' do
        let(:name) { 'overridden name' }

        let(:params) do
          {
            shipment: shipment,
            name: name
          }
        end

        it 'creates link with passed value as a name' do
          expect(shipment_tracking_link_to).to eq('<a href="https://example.com?tracking=Abc">overridden name</a>')
        end
      end

      context 'with tracking_url only' do
        let(:tracking) { nil }
        let(:tracking_url) { 'https://example.com' }

        it 'creates a link with tracking_url as a name' do
          expect(shipment_tracking_link_to).to eq('<a href="https://example.com">https://example.com</a>')
        end
      end

      context 'with no tracking_url' do
        let(:tracking_url) { '' }

        it 'returns empty string' do
          expect(shipment_tracking_link_to).to eq('')
        end
      end

      context 'with options' do
        let(:params) do
          {
            shipment: shipment,
            html_options: { data: { foo: 'bar' } }
          }
        end

        it 'sets options for link' do
          expect(shipment_tracking_link_to).to include(' data-foo="bar"')
        end
      end
    end
  end
end
