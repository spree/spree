require 'spec_helper'

describe Spree::ReimbursementPerformer, :type => :model do
  let(:reimbursement)           { create(:reimbursement, return_items_count: 1) }
  let(:return_item)             { reimbursement.return_items.first }
  let(:reimbursement_type)      { double("ReimbursementType") }
  let(:reimbursement_type_hash) { { reimbursement_type => [return_item]} }

  before do
    expect(Spree::ReimbursementPerformer).to receive(:calculate_reimbursement_types).and_return(reimbursement_type_hash)
  end

  describe ".simulate" do
    subject { Spree::ReimbursementPerformer.simulate(reimbursement) }

    it "reimburses each calculated reimbursement types with the correct return items as a simulation" do
      expect(reimbursement_type).to receive(:reimburse).with(reimbursement, [return_item], true)
      subject
    end
  end

  describe '.perform' do
    subject { Spree::ReimbursementPerformer.perform(reimbursement) }

    it "reimburses each calculated reimbursement types with the correct return items as a simulation" do
      expect(reimbursement_type).to receive(:reimburse).with(reimbursement, [return_item], false)
      subject
    end
  end
end
