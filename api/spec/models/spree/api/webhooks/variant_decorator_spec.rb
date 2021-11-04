require 'spec_helper'

describe Spree::Variant do
  let(:variant) { create(:variant) }

  describe '#discontinue!' do
    context 'emitting variant.discontinued' do
      subject { variant.discontinue! }

      let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant).serializable_hash.to_json }

      it { expect { subject }.to emit_webhook_event('variant.discontinued') }
    end
  end
end
