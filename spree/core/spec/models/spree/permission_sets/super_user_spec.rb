require 'spec_helper'
require 'cancan/matchers'

RSpec.describe Spree::PermissionSets::SuperUser do
  let(:user) { build(:user) }
  let(:ability) { Spree::Ability.new(user) }

  subject(:permission_set) { described_class.new(ability) }

  before { permission_set.activate! }

  describe '#activate!' do
    it 'grants manage access to all resources' do
      expect(ability.can?(:manage, :all)).to be true
    end

    it 'grants manage access to Order' do
      expect(ability.can?(:manage, Spree::Order)).to be true
    end

    it 'grants manage access to Product' do
      expect(ability.can?(:manage, Spree::Product)).to be true
    end

    context 'order restrictions' do
      let(:cancelable_order) { build(:order) }
      let(:non_cancelable_order) { build(:order) }
      let(:deletable_order) { build(:order) }
      let(:non_deletable_order) { build(:order) }

      before do
        allow(cancelable_order).to receive(:allow_cancel?).and_return(true)
        allow(non_cancelable_order).to receive(:allow_cancel?).and_return(false)
        allow(deletable_order).to receive(:can_be_deleted?).and_return(true)
        allow(non_deletable_order).to receive(:can_be_deleted?).and_return(false)
      end

      it 'allows canceling orders that allow cancellation' do
        expect(ability.can?(:cancel, cancelable_order)).to be true
      end

      it 'prevents canceling orders that do not allow cancellation' do
        expect(ability.can?(:cancel, non_cancelable_order)).to be false
      end

      it 'allows destroying orders that can be deleted' do
        expect(ability.can?(:destroy, deletable_order)).to be true
      end

      it 'prevents destroying orders that cannot be deleted' do
        expect(ability.can?(:destroy, non_deletable_order)).to be false
      end
    end

    context 'immutable types' do
      let(:mutable_refund_reason) { build(:refund_reason, mutable: true) }
      let(:immutable_refund_reason) { build(:refund_reason, mutable: false) }

      it 'allows editing mutable refund reasons' do
        expect(ability.can?(:edit, mutable_refund_reason)).to be true
      end

      it 'prevents editing immutable refund reasons' do
        expect(ability.can?(:edit, immutable_refund_reason)).to be false
      end
    end

    context 'admin role protection' do
      let(:admin_role) { build(:role, name: 'admin') }
      let(:other_role) { build(:role, name: 'customer_service') }

      it 'prevents updating the admin role' do
        expect(ability.can?(:update, admin_role)).to be false
      end

      it 'prevents destroying the admin role' do
        expect(ability.can?(:destroy, admin_role)).to be false
      end

      it 'allows updating other roles' do
        expect(ability.can?(:update, other_role)).to be true
      end

      it 'allows destroying other roles' do
        expect(ability.can?(:destroy, other_role)).to be true
      end
    end
  end
end
