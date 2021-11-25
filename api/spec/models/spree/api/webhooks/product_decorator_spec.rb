require 'spec_helper'

describe Spree::Api::Webhooks::ProductDecorator do
  let(:product) { create(:product) }

  context 'emitting product.discontinued' do
    let(:body) { Spree::Api::V2::Platform::ProductSerializer.new(product).serializable_hash }
    let(:event_name) { 'product.discontinued' }

    context 'when product discontinued_on changes' do
      context 'when the new value is "present"' do
        it do
          expect do
            product.discontinue!
          end.to emit_webhook_event(event_name)
        end
      end

      context 'when the new value is not "present"' do
        before { product.update(discontinue_on: Date.yesterday) }

        it do
          expect do
            product.update(discontinue_on: nil)
          end.not_to emit_webhook_event(event_name)
        end
      end
    end

    context 'when product discontinued_on does not change' do
      it do
        expect do
          product.update(width: 180)
        end.not_to emit_webhook_event(event_name)
      end
    end
  end
end
