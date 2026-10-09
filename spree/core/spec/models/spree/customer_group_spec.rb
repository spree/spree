require 'spec_helper'

RSpec.describe Spree::CustomerGroup, type: :model do
  let(:store) { @default_store }
  let(:customer_group) { create(:customer_group, store: store) }

  describe 'validations' do
    it 'validates uniqueness of name within store scope' do
      create(:customer_group, name: 'VIP', store: store)

      expect(build(:customer_group, name: 'VIP', store: store)).not_to be_valid
      expect(build(:customer_group, name: 'VIP', store: create(:store))).to be_valid
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

  describe '#add_customers' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    it 'adds customers to the group and returns how many were added' do
      count = nil
      expect {
        count = customer_group.add_customers([user1.id, user2.id])
      }.to change { customer_group.customer_group_users.count }.by(2)

      expect(count).to eq(2)
      expect(customer_group.users).to include(user1, user2)
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

    it 'removes customers from the group and returns how many were removed' do
      count = nil
      expect {
        count = customer_group.remove_customers([user1.id, user2.id])
      }.to change { customer_group.customer_group_users.count }.by(-2)

      expect(count).to eq(2)
      expect(customer_group.users).not_to include(user1, user2)
      expect(customer_group.users).to include(user3)
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
