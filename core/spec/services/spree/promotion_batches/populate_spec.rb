require 'spec_helper'

module Spree
  describe PromotionBatches::Populate do
    subject { described_class.new.call(promotion_batch: promotion_batch) }

    let!(:template_promotion) { create(:promotion) }
    let(:promotion_batch) { create(:promotion_batch, template_promotion: template_promotion, codes: codes) }
    let(:codes) { ['ABCD', 'EFGH', 'JKLM'] }

    context 'when promotions can be created' do
      it 'creates new promotions' do
        expect { subject }.to change { Spree::Promotion.count }.by(3)
      end

      it 'changes promotion batch status to completed' do
        subject
        expect(promotion_batch.state).to eq('completed')
      end
    end

    context 'when an error happens when copying a promotion' do
      subject { described_class.new(duplicator_class: duplicator_class_double).call(promotion_batch: promotion_batch) }
      let(:duplicator_class_double) { double }
      let(:duplicator_double) { instance_double(Spree::PromotionHandler::PromotionBatchDuplicator) }

      before do
        allow(duplicator_class_double).to receive(:new).and_return(duplicator_double)
        allow(duplicator_double).to receive(:duplicate).and_raise('Test error')
      end

      it 'raises an error and updates batch status to error' do
        expect { subject }.to raise_error('Test error')
        expect(promotion_batch.state).to eq('error')
      end
    end
  end
end
