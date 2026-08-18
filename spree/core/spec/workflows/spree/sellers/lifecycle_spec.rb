require 'spec_helper'

RSpec.describe 'Spree::Sellers workflows' do
  let(:store) { @default_store }
  let(:seller) { create(:seller, store: store) }
  let(:staff) { create(:admin_user) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe Spree::Sellers::Invite do
    subject(:result) { described_class.call(seller: seller, email: 'seller@example.com', inviter: staff) }

    it 'sends an invitation to the seller and marks it invited' do
      expect(result).to be_success
      expect(seller.reload).to be_invited
      expect(seller.invitations.last.email).to eq('seller@example.com')
    end

    it "invites into the seller's own admin role, not the store's" do
      expect(result.value.invitations.last.role.resource).to eq(seller)
    end

    it 'refuses a role belonging to somewhere else' do
      store_role = Spree::Role.default_admin_role(store)

      outcome = described_class.call(seller: seller, email: 'seller@example.com', inviter: staff, role: store_role)

      expect(outcome).to be_failure
      expect(seller.reload).to be_pending
    end

    it 'refuses a seller already trading' do
      seller.update!(status: 'approved')

      expect(described_class.call(seller: seller, email: 'seller@example.com', inviter: staff)).to be_failure
    end

    it 're-invites one whose first invitation went astray' do
      result
      expect(described_class.call(seller: seller, email: 'other@example.com', inviter: staff)).to be_success
    end

    it 'runs validate handlers before anything is written' do
      Spree.hooks.register('sellers.invite.validate') { |workflow| workflow.reject!('not this one') }

      expect(result).to be_failure
      expect(seller.reload).to be_pending
      expect(seller.invitations).to be_empty
    end
  end

  describe Spree::Sellers::Approve do
    it 'lets an applicant under review trade' do
      seller.update!(status: 'ready_for_review')

      expect(described_class.call(seller: seller)).to be_success
      expect(seller.reload).to be_approved
    end

    it 'lifts a suspension, and the holiday it was hiding behind' do
      seller.update!(status: 'suspended', holiday_mode_until: 2.weeks.from_now)

      expect(described_class.call(seller: seller)).to be_success
      expect(seller.reload).to be_sellable
    end

    it 'refuses one already approved' do
      seller.update!(status: 'approved')

      expect(described_class.call(seller: seller)).to be_failure
    end

    it 'refuses one that has not been invited yet' do
      expect(described_class.call(seller: seller)).to be_failure
    end
  end

  describe Spree::Sellers::Suspend do
    before { seller.update!(status: 'approved') }

    it 'stops a trading seller' do
      expect(described_class.call(seller: seller)).to be_success
      expect(seller.reload).to be_suspended
      expect(seller).not_to be_sellable
    end

    it 'keeps the reason with the seller' do
      described_class.call(seller: seller, reason: 'Counterfeit goods')

      expect(seller.reload.metadata['suspension_reason']).to eq('Counterfeit goods')
    end

    it 'refuses one already suspended' do
      seller.update!(status: 'suspended')

      expect(described_class.call(seller: seller)).to be_failure
    end
  end

  describe Spree::Sellers::Reject do
    it 'turns down an applicant' do
      seller.update!(status: 'ready_for_review')

      expect(described_class.call(seller: seller, reason: 'Incomplete paperwork')).to be_success
      expect(seller.reload).to be_rejected
      expect(seller.metadata['rejection_reason']).to eq('Incomplete paperwork')
    end

    # A trading seller is suspended instead — reversible, and a different
    # thing to tell them.
    it 'refuses one already approved' do
      seller.update!(status: 'approved')

      expect(described_class.call(seller: seller)).to be_failure
    end

    it 'can be undone by approving' do
      seller.update!(status: 'ready_for_review')
      described_class.call(seller: seller)

      expect(Spree::Sellers::Approve.call(seller: seller.reload)).to be_success
      expect(seller.reload).to be_approved
    end
  end

  describe 'lifecycle hooks' do
    it 'reports each transition to its own hook' do
      seen = []
      %w[invite approve suspend reject].each do |action|
        Spree.hooks.register("sellers.#{action}.after_#{action}") { |_workflow| seen << action }
      end

      Spree::Sellers::Invite.call(seller: seller, email: 'seller@example.com', inviter: staff)
      seller.update!(status: 'ready_for_review')
      Spree::Sellers::Approve.call(seller: seller)
      Spree::Sellers::Suspend.call(seller: seller.reload)
      Spree::Sellers::Reject.call(seller: create(:seller, store: store))

      expect(seen).to eq(%w[invite approve suspend reject])
    end
  end
end
