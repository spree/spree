require 'spec_helper'

describe Spree::GiftCards::BulkGenerateJob, type: :job do
  subject { described_class.new }

  describe '#perform' do
    let(:gift_card_batch) { create(:gift_card_batch, codes_count: 2, prefix: 'batch_', amount: 10) }

    it 'generates gift cards' do
      expect { subject.perform(gift_card_batch.id) }.to change(Spree::GiftCard, :count).by(2)
    end
  end
end
