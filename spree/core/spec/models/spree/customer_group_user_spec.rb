require 'spec_helper'

RSpec.describe Spree::CustomerGroupUser, type: :model do
  let(:customer_group) { create(:customer_group) }
  let(:user) { create(:user) }

  describe 'validations' do
    context 'uniqueness' do
      let!(:existing) { create(:customer_group_user, customer_group: customer_group, customer: user) }

      it 'validates uniqueness of customer_group_id within user scope' do
        duplicate = build(:customer_group_user, customer_group: customer_group, customer: user)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:customer_group_id]).to include('has already been taken')
      end

      it 'allows same user in different groups' do
        other_group = create(:customer_group)
        new_membership = build(:customer_group_user, customer_group: other_group, customer: user)
        expect(new_membership).to be_valid
      end
    end
  end
end
