require 'spec_helper'

describe Spree::ReturnItem::EligibilityValidator::NoReimbursements do
  let(:validator) { described_class.new(return_item) }

  describe '#eligible_for_return?' do
    subject { validator.eligible_for_return? }

    context 'inventory unit has already been reimbursed' do
      let(:reimbursement) { create(:reimbursement) }
      let(:return_item)   { reimbursement.return_items.last }

      it 'returns false' do
        expect(subject).to eq false
      end

      it 'sets an error' do
        subject
        expect(validator.errors[:inventory_unit_reimbursed]).to eq Spree.t('return_item_inventory_unit_reimbursed')
      end
    end

    context 'inventory unit has not been reimbursed' do
      let(:return_item) { create(:return_item) }

      it 'returns true' do
        expect(subject).to eq true
      end
    end
  end

  describe '#requires_manual_intervention?' do
    subject { validator.requires_manual_intervention? }

    context 'not eligible for return' do
      let(:reimbursement) { create(:reimbursement) }
      let(:return_item)   { reimbursement.return_items.last }

      before do
        validator.eligible_for_return?
      end

      it 'returns true if errors were added' do
        expect(subject).to eq true
      end
    end

    context 'eligible for return' do
      let(:return_item) { create(:return_item) }

      before do
        validator.eligible_for_return?
      end

      it 'returns false if no errors were added' do
        expect(subject).to eq false
      end
    end
  end
end
