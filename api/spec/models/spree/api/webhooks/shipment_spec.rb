require 'spec_helper'

class TextFormatter
end

describe Spree::Shipment do
  let(:shipment) { create(:shipment) }

  context '#after_ship' do
    before do
      # redefine the after_ship method body to assert super is being used
      described_class.class_eval do
        def after_ship
          TextFormatter.new.to_s
        end
      end

      allow(Spree::Webhooks::Endpoints::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
    end

    let(:payload) { {} }
    let(:queue_requests) { instance_double(Spree::Webhooks::Endpoints::QueueRequests) }

    it 'executes QueueRequests.call with a shipment.ship event and {} payload after calling super' do
      expect(TextFormatter).to(
        receive(:new).and_return(
          double(:scope).tap { |scope| expect(scope).to receive(:to_s) }
        )
      )
      shipment.cancel # previous state that allows the object be shipped
      shipment.ship
      expect(queue_requests).to have_received(:call).with(event: 'shipment.ship', payload: payload).once
    end
  end
end
