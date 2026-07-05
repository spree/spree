require 'spec_helper'

describe Spree::OrderApproval, type: :model do
  let(:order) { create(:order) }

  describe 'validations' do
    it 'requires status' do
      approval = described_class.new(order: order, status: nil)
      expect(approval).not_to be_valid
      expect(approval.errors[:status]).to include("can't be blank")
    end

    it 'rejects invalid status values' do
      approval = described_class.new(order: order, status: 'maybe')
      expect(approval).not_to be_valid
      expect(approval.errors[:status]).to include('is not included in the list')
    end

    it 'accepts each STATUSES value' do
      Spree::OrderApproval::STATUSES.each do |status|
        approval = described_class.new(order: order, status: status)
        approval.valid?
        expect(approval.errors[:status]).to be_empty
      end
    end
  end

  describe 'scopes' do
    let!(:pending)  { described_class.create!(order: order, status: 'pending') }
    let!(:approved) { described_class.create!(order: order, status: 'approved') }
    let!(:rejected) { described_class.create!(order: order, status: 'rejected') }

    it { expect(described_class.approved).to contain_exactly(approved) }
    it { expect(described_class.pending).to contain_exactly(pending) }
    it { expect(described_class.rejected).to contain_exactly(rejected) }
  end

  describe 'prefixed id' do
    it 'has appr_ prefix' do
      approval = described_class.create!(order: order, status: 'approved')
      expect(approval.prefixed_id).to start_with('appr_')
    end
  end

  describe 'polymorphic approver' do
    let(:admin) { create(:admin_user) }

    it 'records the approver' do
      approval = described_class.create!(order: order, status: 'approved', approver: admin, decided_at: Time.current)
      expect(approval.approver).to eq(admin)
    end
  end
end
