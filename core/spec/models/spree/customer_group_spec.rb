require 'spec_helper'

RSpec.describe Spree::CustomerGroup, type: :model do
  let(:store) { create(:store) }
  let(:customer_group) { create(:customer_group, store: store) }

  describe 'associations' do
    it { is_expected.to belong_to(:store).optional(false) }
    it { is_expected.to have_many(:customer_group_users).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:customer_group_users) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:store) }

    context 'uniqueness' do
      let!(:existing_group) { create(:customer_group, name: 'VIP', store: store) }

      it 'validates uniqueness of name within store scope' do
        new_group = build(:customer_group, name: 'VIP', store: store)
        expect(new_group).not_to be_valid
        expect(new_group.errors[:name]).to include('has already been taken')
      end

      it 'allows same name in different store' do
        other_store = create(:store)
        new_group = build(:customer_group, name: 'VIP', store: other_store)
        expect(new_group).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.for_store' do
      let!(:group1) { create(:customer_group, store: store) }
      let!(:group2) { create(:customer_group, store: create(:store)) }

      it 'returns groups for the specified store' do
        expect(described_class.for_store(store)).to include(group1)
        expect(described_class.for_store(store)).not_to include(group2)
      end
    end
  end

  describe '#users_count' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    before do
      customer_group.users << user1
      customer_group.users << user2
    end

    it 'returns the number of users in the group' do
      expect(customer_group.users_count).to eq(2)
    end
  end

  describe 'soft delete' do
    it 'supports soft deletion' do
      customer_group.destroy
      expect(described_class.with_deleted.find(customer_group.id)).to be_present
      expect(described_class.find_by(id: customer_group.id)).to be_nil
    end
  end

  describe '#add_customers' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    it 'adds customers to the group' do
      expect {
        customer_group.add_customers([user1.id, user2.id])
      }.to change { customer_group.customer_group_users.count }.by(2)

      expect(customer_group.users).to include(user1, user2)
    end

    it 'returns the count of added customers' do
      count = customer_group.add_customers([user1.id, user2.id])
      expect(count).to eq(2)
    end

    it 'skips users already in the group' do
      customer_group.add_customers([user1.id])

      expect {
        customer_group.add_customers([user1.id, user2.id])
      }.to change { customer_group.customer_group_users.count }.by(1)

      expect(customer_group.users.count).to eq(2)
    end

    it 'returns 0 when no users are added' do
      customer_group.add_customers([user1.id])
      count = customer_group.add_customers([user1.id])
      expect(count).to eq(0)
    end

    it 'handles empty array' do
      count = customer_group.add_customers([])
      expect(count).to eq(0)
    end

    it 'handles nil' do
      count = customer_group.add_customers(nil)
      expect(count).to eq(0)
    end

    it 'touches the added users' do
      user1.update_column(:updated_at, 1.day.ago)
      user2.update_column(:updated_at, 1.day.ago)
      original_updated_at = user1.reload.updated_at

      customer_group.add_customers([user1.id, user2.id])

      expect(user1.reload.updated_at).to be > original_updated_at
      expect(user2.reload.updated_at).to be > original_updated_at
    end

    it 'does not touch users that were already in the group' do
      customer_group.add_customers([user1.id])
      user1.update_column(:updated_at, 1.day.ago)
      original_updated_at = user1.reload.updated_at

      customer_group.add_customers([user1.id, user2.id])

      expect(user1.reload.updated_at).to eq(original_updated_at)
    end
  end

  describe '#remove_customers' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    before do
      customer_group.add_customers([user1.id, user2.id, user3.id])
    end

    it 'removes customers from the group' do
      expect {
        customer_group.remove_customers([user1.id, user2.id])
      }.to change { customer_group.customer_group_users.count }.by(-2)

      expect(customer_group.users).not_to include(user1, user2)
      expect(customer_group.users).to include(user3)
    end

    it 'returns the count of removed customers' do
      count = customer_group.remove_customers([user1.id, user2.id])
      expect(count).to eq(2)
    end

    it 'returns 0 when users are not in the group' do
      other_user = create(:user)
      count = customer_group.remove_customers([other_user.id])
      expect(count).to eq(0)
    end

    it 'handles empty array' do
      count = customer_group.remove_customers([])
      expect(count).to eq(0)
    end

    it 'handles nil' do
      count = customer_group.remove_customers(nil)
      expect(count).to eq(0)
    end

    it 'touches the removed users' do
      user1.update_column(:updated_at, 1.day.ago)
      user2.update_column(:updated_at, 1.day.ago)
      original_updated_at = user1.reload.updated_at

      customer_group.remove_customers([user1.id, user2.id])

      expect(user1.reload.updated_at).to be > original_updated_at
      expect(user2.reload.updated_at).to be > original_updated_at
    end

    it 'does not touch users that were not in the group' do
      other_user = create(:user)
      other_user.update_column(:updated_at, 1.day.ago)
      original_updated_at = other_user.reload.updated_at

      customer_group.remove_customers([other_user.id])

      expect(other_user.reload.updated_at).to eq(original_updated_at)
    end
  end
end
