require 'spec_helper'

module Spree
  describe PromotionBatches::CreateWithCodes, :job do
    subject { described_class.new.call(template_promotion: template_promotion, codes: codes) }

    let(:template_promotion) { create(:promotion) }

    context 'when an empty list of codes is provided' do
      let(:codes) { [] }

      it 'raises an error' do
        expect { subject }.to raise_error(Spree::PromotionBatches::CreateWithCodes::Error)
      end
    end

    context 'when a list of codes is provided' do
      let(:codes) { ['XXX', 'ZZZ'] }

      it 'creates a promotion batch' do
        expect(subject.codes).to eq(codes)
        expect(subject.template_promotion).to eq(template_promotion)
        expect(subject.state).to eq('pending')
      end

      it 'enqueues a job to populate promotion batch' do
        expect { subject }.to have_enqueued_job(Spree::PromotionBatches::PopulateJob)
      end
    end
  end
end
