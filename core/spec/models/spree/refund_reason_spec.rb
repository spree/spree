require 'spec_helper'

describe Spree::RefundReason do
  let!(:refund_reason) { create(:refund_reason, active: true) }

  describe 'Included Modules' do
    it { expect(described_class.ancestors).to include(Spree::NamedType) }
  end

  describe 'Constants' do
    it { expect(described_class::RETURN_PROCESSING_REASON).to eql('Return processing') }
  end

  describe 'Associations' do
    it { is_expected.to have_many(:refunds).dependent(:restrict_with_error) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.allow_blank }
  end

  describe 'Scopes' do
    let!(:refund_reason2) { create(:refund_reason, active: false) }

    describe 'active' do
      it { expect(described_class.active).to include(refund_reason) }
      it { expect(described_class.active).not_to include(refund_reason2) }
    end
  end

  describe 'Class Methods' do
    describe '.return_processing_reason' do
      context 'default refund reason present' do
        let!(:default_refund_reason) { create(:default_refund_reason) }
        it { expect(described_class.return_processing_reason).to eq(default_refund_reason) }
      end

      context 'default refund reason not present' do
        it { expect { described_class.return_processing_reason }.to raise_error(ActiveRecord::RecordNotFound) }
      end
    end
  end
end
