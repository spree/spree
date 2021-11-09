require 'spec_helper'

describe Spree::Api::Webhooks::VariantDecorator do
  let(:variant) { create(:variant) }

  context 'emitting variant.discontinued' do
    let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant).serializable_hash.to_json }

    context 'when variant discontinued_on changes' do
      context 'when the new value is "present"' do
        it do
          expect do
            variant.discontinue!
          end.to emit_webhook_event('variant.discontinued')
        end
      end

      context 'when the new value is not "present"' do
        before { variant.update(discontinue_on: Date.yesterday) }

        it do
          expect do
            variant.update(discontinue_on: nil)
          end.not_to emit_webhook_event('variant.discontinued')
        end
      end
    end

    context 'when variant discontinued_on does not change' do
      it do
        expect do
          variant.update(width: 180)
        end.not_to emit_webhook_event('variant.discontinued')
      end
    end
  end
end
