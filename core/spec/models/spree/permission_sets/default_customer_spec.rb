require 'spec_helper'
require 'cancan/matchers'

RSpec.describe Spree::PermissionSets::DefaultCustomer do
  let(:user) { create(:user) }
  let(:ability) { Spree::Ability.new(user) }

  subject(:permission_set) { described_class.new(ability) }

  before { permission_set.activate! }

  describe '#activate!' do
    context 'catalog read access' do
      it 'grants read access to Country' do
        expect(ability.can?(:read, Spree::Country)).to be true
      end

      it 'grants read access to Product' do
        expect(ability.can?(:read, Spree::Product)).to be true
      end

      it 'grants read access to Variant' do
        expect(ability.can?(:read, Spree::Variant)).to be true
      end

      it 'grants read access to Taxon' do
        expect(ability.can?(:read, Spree::Taxon)).to be true
      end

      it 'grants read access to Store' do
        expect(ability.can?(:read, Spree::Store)).to be true
      end
    end

    context 'order permissions' do
      it 'allows creating orders' do
        expect(ability.can?(:create, Spree::Order)).to be true
      end

      context 'with user order' do
        let(:order) { build(:order, user: user) }

        it 'allows viewing own order' do
          expect(ability.can?(:show, order)).to be true
        end

        it 'allows updating own incomplete order' do
          allow(order).to receive(:completed?).and_return(false)
          expect(ability.can?(:update, order)).to be true
        end

        it 'prevents updating own completed order' do
          allow(order).to receive(:completed?).and_return(true)
          expect(ability.can?(:update, order)).to be false
        end
      end

      context 'with token' do
        let(:order) { build(:order, user: nil, token: 'secret') }

        it 'allows viewing order with correct token' do
          expect(ability.can?(:show, order, 'secret')).to be true
        end

        it 'allows updating incomplete order with correct token' do
          allow(order).to receive(:completed?).and_return(false)
          expect(ability.can?(:update, order, 'secret')).to be true
        end

        it 'prevents viewing order with incorrect token' do
          expect(ability.can?(:show, order, 'wrong')).to be false
        end
      end
    end

    context 'user account permissions' do
      it 'allows viewing own user' do
        expect(ability.can?(:show, user)).to be true
      end

      it 'allows updating own user' do
        expect(ability.can?(:update, user)).to be true
      end

      it 'allows destroying own user' do
        expect(ability.can?(:destroy, user)).to be true
      end

      it 'prevents viewing other user' do
        other_user = create(:user)
        expect(ability.can?(:show, other_user)).to be false
      end

      it 'allows creating new user' do
        expect(ability.can?(:create, Spree.user_class)).to be true
      end
    end

    context 'with non-persisted user' do
      let(:guest_user) { build(:user) }
      let(:guest_ability) { Spree::Ability.new(guest_user) }
      let(:guest_permission_set) { described_class.new(guest_ability) }

      before { guest_permission_set.activate! }

      it 'allows viewing self' do
        expect(guest_ability.can?(:show, guest_user)).to be true
      end

      it 'allows updating self' do
        expect(guest_ability.can?(:update, guest_user)).to be true
      end
    end

    context 'address permissions' do
      let(:own_address) { build(:address, user_id: user.id) }
      let(:other_address) { build(:address, user_id: create(:user).id) }

      it 'allows managing own address' do
        expect(ability.can?(:manage, own_address)).to be true
      end

      it 'prevents managing other user address' do
        expect(ability.can?(:manage, other_address)).to be false
      end
    end

    context 'credit card permissions' do
      let(:own_card) { build(:credit_card, user_id: user.id) }
      let(:other_card) { build(:credit_card, user_id: create(:user).id) }

      it 'allows reading own credit card' do
        expect(ability.can?(:read, own_card)).to be true
      end

      it 'allows destroying own credit card' do
        expect(ability.can?(:destroy, own_card)).to be true
      end

      it 'prevents reading other user credit card' do
        expect(ability.can?(:read, other_card)).to be false
      end
    end

    context 'wishlist permissions' do
      let(:own_wishlist) { build(:wishlist, user: user) }
      let(:public_wishlist) { build(:wishlist, user: create(:user), is_private: false) }
      let(:private_wishlist) { build(:wishlist, user: create(:user), is_private: true) }

      it 'allows managing own wishlist' do
        expect(ability.can?(:manage, own_wishlist)).to be true
      end

      it 'allows viewing public wishlist' do
        expect(ability.can?(:show, public_wishlist)).to be true
      end

      it 'prevents viewing private wishlist' do
        expect(ability.can?(:show, private_wishlist)).to be false
      end
    end

    context 'admin permissions' do
      it 'does not grant admin access' do
        expect(ability.can?(:admin, :all)).to be false
      end

      it 'does not grant manage access to Product' do
        expect(ability.can?(:manage, Spree::Product)).to be false
      end
    end
  end
end
