require 'spec_helper'

module Spree
  describe PromotionBatches::CreateWithRandomCodes, :job do
    subject do
      described_class.new(generate_codes: generate_codes_double)
                     .call(template_promotion: template_promotion, amount: amount, random_characters: random_characters, prefix: prefix, suffix: suffix)
    end
    let(:generate_codes_double) { instance_double(Spree::PromotionBatches::GenerateCodes) }

    let(:template_promotion) { create(:promotion) }
    let(:amount) { 3 }
    let(:random_characters) { 4 }
    let(:prefix) { 'XXX' }
    let(:suffix) { 'ZZZ' }
    let(:generated_codes) { ['XXX_AAA_ZZZ', 'XXX_BBB_ZZZ', 'XXX_CCC_ZZZ'] }

    before do
      allow(generate_codes_double).to receive(:call).with(amount: amount, random_characters: random_characters, prefix: prefix, suffix: suffix)
                                                    .and_return(generated_codes)
    end

    it 'creates a promotion batch' do
      expect(subject.codes).to eq(generated_codes)
      expect(subject.template_promotion).to eq(template_promotion)
      expect(subject.state).to eq('pending')
    end

    it 'enqueues a job to populate promotion batch' do
      expect { subject }.to have_enqueued_job(Spree::PromotionBatches::PopulateJob)
    end
  end
end
