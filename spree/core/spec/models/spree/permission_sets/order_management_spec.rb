require 'spec_helper'
require 'cancan/matchers'

RSpec.describe Spree::PermissionSets::OrderManagement do
  let(:user) { build(:user) }
  let(:ability) { Spree::Ability.new(user) }

  subject(:permission_set) { described_class.new(ability) }

  before { permission_set.activate! }

  describe '#activate!' do
    it 'grants manage access to Order' do
      expect(ability.can?(:manage, Spree::Order)).to be true
    end

    it 'grants manage access to Payment' do
      expect(ability.can?(:manage, Spree::Payment)).to be true
    end

    it 'grants manage access to Shipment' do
      expect(ability.can?(:manage, Spree::Shipment)).to be true
    end

    it 'grants manage access to Adjustment' do
      expect(ability.can?(:manage, Spree::Adjustment)).to be true
    end

    it 'grants manage access to LineItem' do
      expect(ability.can?(:manage, Spree::LineItem)).to be true
    end

    it 'grants manage access to ReturnAuthorization' do
      expect(ability.can?(:manage, Spree::ReturnAuthorization)).to be true
    end

    it 'grants manage access to CustomerReturn' do
      expect(ability.can?(:manage, Spree::CustomerReturn)).to be true
    end

    it 'grants manage access to Reimbursement' do
      expect(ability.can?(:manage, Spree::Reimbursement)).to be true
    end

    it 'grants manage access to Refund' do
      expect(ability.can?(:manage, Spree::Refund)).to be true
    end

    it 'does not grant manage access to Product' do
      expect(ability.can?(:manage, Spree::Product)).to be false
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

    context 'order-owned record restrictions on canceled orders' do
      let(:canceled_order) { build(:order) }
      let(:active_order) { build(:order) }

      before do
        ability.can :manage, Spree::OrderPromotion
        permission_set.activate!
        allow(canceled_order).to receive(:canceled?).and_return(true)
        allow(active_order).to receive(:canceled?).and_return(false)
      end

      described_class::RESTRICTED_MODELS.each do |klass|
        context klass.name do
          let(:record_on_canceled_order) { klass.new.tap { |r| allow(r).to receive(:order).and_return(canceled_order) } }
          let(:record_on_active_order) { klass.new.tap { |r| allow(r).to receive(:order).and_return(active_order) } }

          it 'prevents managing records on canceled orders' do
            expect(ability.can?(:create, record_on_canceled_order)).to be false
            expect(ability.can?(:edit, record_on_canceled_order)).to be false
            expect(ability.can?(:destroy, record_on_canceled_order)).to be false
          end

          it 'allows managing records on non-canceled orders' do
            expect(ability.can?(:create, record_on_active_order)).to be true
            expect(ability.can?(:edit, record_on_active_order)).to be true
            expect(ability.can?(:destroy, record_on_active_order)).to be true
          end
        end
      end
    end
  end
end
