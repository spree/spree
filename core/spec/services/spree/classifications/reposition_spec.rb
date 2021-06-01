require 'spec_helper'

module Spree
  describe Classifications::Reposition do
    subject { described_class }

    let(:classification) { create(:classification) }

    context 'success' do
      let(:call) { described_class.call(classification: classification, position: 3) }

      it { expect(call.success?).to be_truthy }
      it { expect(call.value).to eq(classification) }
      it { expect { call }.to change(classification.reload, :position).to(4) }
    end

    context 'failure' do
      let(:call) { described_class.call(classification: classification, position: 'invalid') }

      it { expect(call.success?).to be_falsey }
      it { expect(call.error.to_s).to eq('is not a number') }
    end
  end
end
