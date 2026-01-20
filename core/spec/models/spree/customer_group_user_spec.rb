require 'spec_helper'

RSpec.describe Spree::CustomerGroupUser, type: :model do
  let(:customer_group) { create(:customer_group) }
  let(:user) { create(:user) }

  describe 'associations' do
    it { is_expected.to belong_to(:customer_group).optional(false) }
    it { is_expected.to belong_to(:user).optional(false) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:customer_group) }
    it { is_expected.to validate_presence_of(:user) }

    context 'uniqueness' do
      let!(:existing) { create(:customer_group_user, customer_group: customer_group, user: user) }

      it 'validates uniqueness of customer_group_id within user scope' do
        duplicate = build(:customer_group_user, customer_group: customer_group, user: user)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:customer_group_id]).to include('has already been taken')
      end

      it 'allows same user in different groups' do
        other_group = create(:customer_group)
        new_membership = build(:customer_group_user, customer_group: other_group, user: user)
        expect(new_membership).to be_valid
      end
    end
  end
end
