require 'spec_helper'

describe Spree::Variant do
  let(:variant) { create(:variant) }

  describe '#discontinue!' do
    context 'emitting variant.discontinued' do
      subject { variant.discontinue! }

      let(:params) { 'variant.discontinued' }
      let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant, mock_serializer_params(event: params)).serializable_hash.to_json }

      it { expect { subject }.to emit_webhook_event(params) }
    end
  end
end
