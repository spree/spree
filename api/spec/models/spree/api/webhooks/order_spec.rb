require 'spec_helper'

class TextFormatter
end

xdescribe Spree::Order do
  describe 'sending webhooks after transitioning from states' do
    let(:order) { Spree::Order.create }
    let(:payload) { {} }
    let(:queue_requests) { instance_double(Spree::Webhooks::Endpoints::QueueRequests) }

    shared_examples 'queues a webhook request' do |event, method_name|
      before do
        allow(Spree::Webhooks::Endpoints::QueueRequests).to receive(:new).and_return(queue_requests)
        allow(queue_requests).to receive(:call).with(any_args)
        # redefine `method_name` method body to assert super is being used
        # [TODO]: find another way to test super is being used
        #         this makes other tests relying on `method_name` fail
        described_class.class_eval do
          define_method(method_name) do
            TextFormatter.new.to_s
          end
        end
      end

      it "executes QueueRequests.call with a order.#{event} event and {} payload after calling super" do
        expect(TextFormatter).to(
          receive(:new).and_return(
            double(:scope).tap { |scope| expect(scope).to receive(:to_s) }
          )
        )
        order.send(method_name)
        expect(queue_requests).to have_received(:call).with(event: "order.#{event}", payload: payload).once
      end
    end

    context '#cancel' do
      include_examples 'queues a webhook request', :cancel, :cancel
    end

    context '#finalize!' do
      before { order.update_column :state, 'complete' }

      include_examples 'queues a webhook request', :complete, :finalize!
    end
  end
end
