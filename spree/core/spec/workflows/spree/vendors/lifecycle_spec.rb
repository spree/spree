require 'spec_helper'

RSpec.describe 'Spree::Vendors workflows' do
  let(:store) { @default_store }
  let(:vendor) { create(:vendor, store: store) }
  let(:staff) { create(:admin_user) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe Spree::Vendors::Invite do
    subject(:result) { described_class.call(vendor: vendor, email: 'seller@example.com', inviter: staff) }

    it 'sends an invitation to the vendor and marks it invited' do
      expect(result).to be_success
      expect(vendor.reload).to be_invited
      expect(vendor.invitations.last.email).to eq('seller@example.com')
    end

    it "invites into the vendor's own admin role, not the store's" do
      expect(result.value.invitations.last.role.resource).to eq(vendor)
    end

    it 'refuses a role belonging to somewhere else' do
      store_role = Spree::Role.default_admin_role(store)

      outcome = described_class.call(vendor: vendor, email: 'seller@example.com', inviter: staff, role: store_role)

      expect(outcome).to be_failure
      expect(vendor.reload).to be_pending
    end

    it 'refuses a vendor already trading' do
      vendor.update!(status: 'approved')

      expect(described_class.call(vendor: vendor, email: 'seller@example.com', inviter: staff)).to be_failure
    end

    it 're-invites one whose first invitation went astray' do
      result
      expect(described_class.call(vendor: vendor, email: 'other@example.com', inviter: staff)).to be_success
    end

    it 'runs validate handlers before anything is written' do
      Spree.hooks.register('vendors.invite.validate') { |workflow| workflow.reject!('not this one') }

      expect(result).to be_failure
      expect(vendor.reload).to be_pending
      expect(vendor.invitations).to be_empty
    end
  end

  describe Spree::Vendors::Approve do
    it 'lets an applicant under review trade' do
      vendor.update!(status: 'ready_for_review')

      expect(described_class.call(vendor: vendor)).to be_success
      expect(vendor.reload).to be_approved
    end

    it 'lifts a suspension, and the holiday it was hiding behind' do
      vendor.update!(status: 'suspended', holiday_mode_until: 2.weeks.from_now)

      expect(described_class.call(vendor: vendor)).to be_success
      expect(vendor.reload).to be_sellable
    end

    it 'refuses one already approved' do
      vendor.update!(status: 'approved')

      expect(described_class.call(vendor: vendor)).to be_failure
    end

    it 'refuses one that has not been invited yet' do
      expect(described_class.call(vendor: vendor)).to be_failure
    end
  end

  describe Spree::Vendors::Suspend do
    before { vendor.update!(status: 'approved') }

    it 'stops a trading vendor' do
      expect(described_class.call(vendor: vendor)).to be_success
      expect(vendor.reload).to be_suspended
      expect(vendor).not_to be_sellable
    end

    it 'keeps the reason with the vendor' do
      described_class.call(vendor: vendor, reason: 'Counterfeit goods')

      expect(vendor.reload.metadata['suspension_reason']).to eq('Counterfeit goods')
    end

    it 'refuses one already suspended' do
      vendor.update!(status: 'suspended')

      expect(described_class.call(vendor: vendor)).to be_failure
    end
  end

  describe Spree::Vendors::Reject do
    it 'turns down an applicant' do
      vendor.update!(status: 'ready_for_review')

      expect(described_class.call(vendor: vendor, reason: 'Incomplete paperwork')).to be_success
      expect(vendor.reload).to be_rejected
      expect(vendor.metadata['rejection_reason']).to eq('Incomplete paperwork')
    end

    # A trading vendor is suspended instead — reversible, and a different
    # thing to tell them.
    it 'refuses one already approved' do
      vendor.update!(status: 'approved')

      expect(described_class.call(vendor: vendor)).to be_failure
    end

    it 'can be undone by approving' do
      vendor.update!(status: 'ready_for_review')
      described_class.call(vendor: vendor)

      expect(Spree::Vendors::Approve.call(vendor: vendor.reload)).to be_success
      expect(vendor.reload).to be_approved
    end
  end

  describe 'lifecycle hooks' do
    it 'reports each transition to its own hook' do
      seen = []
      %w[invite approve suspend reject].each do |action|
        Spree.hooks.register("vendors.#{action}.after_#{action}") { |_workflow| seen << action }
      end

      Spree::Vendors::Invite.call(vendor: vendor, email: 'seller@example.com', inviter: staff)
      vendor.update!(status: 'ready_for_review')
      Spree::Vendors::Approve.call(vendor: vendor)
      Spree::Vendors::Suspend.call(vendor: vendor.reload)
      Spree::Vendors::Reject.call(vendor: create(:vendor, store: store))

      expect(seen).to eq(%w[invite approve suspend reject])
    end
  end
end
