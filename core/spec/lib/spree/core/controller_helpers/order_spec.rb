require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Order
end

describe Spree::Core::ControllerHelpers::Order, type: :controller do
  controller(FakesController) {}

  let(:user)        { create(:user)              }
  let(:order)       { create(:order, user: user) }
  let(:guest_token) { nil                        }

  before do
    allow(controller).to receive_messages(try_spree_current_user: user)
    allow(controller).to receive_message_chain(:cookies, :signed)
      .and_return(guest_token: guest_token)
  end

  shared_examples_for 'idempotent method' do
    it 'is idempotent' do
      expect(apply).to be(apply)
    end
  end

  describe '#current_order' do
    def apply
      controller.current_order
    end

    shared_examples_for 'order found' do
      it 'returns an order' do
        expect(apply).to be_instance_of(Spree::Order)
      end

      it 'returns a persisted order' do
        expect(apply.persisted?).to be(true)
      end

      it 'sets the created_by attribute in the order' do
        expect(apply.created_by).to be(user)
      end

      it 'sets the last_ip_address attribute in the order' do
        expect(apply.last_ip_address).to eql('0.0.0.0')
      end

      it 'eager loads all adjustments' do
        expect(apply.association(:all_adjustments).loaded?).to be(true)
      end
    end

    shared_examples_for 'order not found' do
      it 'returns nil' do
        expect(apply).to be_nil
      end
    end

    shared_examples_for 'incomplete order returned' do
      include_examples 'order found'

      it 'returns the incomplete order' do
        expect(apply).to eql(order)
      end

      it 'locks the order' do
        relation = double('relation').as_null_object
        expect(user).to receive(:spree_orders).and_return(relation)
        expect(apply).to be(relation)
        expect(relation).to have_received(:lock).with(no_args)
      end

      it 'raises error on lock error' do
        relation = double('relation').as_null_object
        expect(user).to receive(:spree_orders).and_return(relation)
        expect(relation).to receive(:lock).and_raise(
          ActiveRecord::StatementInvalid.new('PG::LockNotAvailable:')
        )
        expect { apply }.to raise_error(Spree::Order::OrderBusyError)
      end
    end

    shared_examples_for 'anonymous order returned' do
      include_examples 'order found'

      # Prevent user.incomplete_spree_orders from accessing
      # Spree::Order.incomplete, allowing the lock count to be asserted
      def stub_incomplete_spree_orders
        if user
          allow(user).to receive_messages(
            incomplete_spree_orders: double.as_null_object
          )
        end
      end

      it 'returns the anonymous order' do
        expect(apply).to eql(anonymous_order)
      end

      it 'locks the order' do
        stub_incomplete_spree_orders
        relation = double('relation').as_null_object
        stub_const('Spree::Order', relation)
        expect(apply).to be(relation)
        expect(relation).to have_received(:lock).with(no_args)
      end

      it 'raises error on lock error' do
        error = ActiveRecord::StatementInvalid.new('other')
        relation = double('relation').as_null_object
        stub_const('Spree::Order', relation)
        expect(relation).to receive(:lock).and_raise(error)
        expect { apply }.to raise_error(error)
      end
    end

    shared_context 'blank guest token' do
      let(:guest_token) { '' }
    end

    shared_context 'non-blank guest token' do
      let(:guest_token) { 'ABC123' }
    end

    shared_context 'setup anonymous order' do
      let!(:anonymous_order) do
        create(
          :order_with_totals,
          guest_token: guest_token,
          user:        nil,
          email:       nil
        )
      end
    end

    context 'when the user is present' do
      # This record should never be returned due to the incomplete
      # scope being used on the order lookup
      let!(:completed_order) do
        create(:order, completed_at: Time.at(0), user: user)
      end

      context 'with no incomplete orders' do
        let!(:order) { nil }

        context 'with no guest token' do
          include_context  'blank guest token'
          include_examples 'order not found'
          include_examples 'idempotent method'
        end

        context 'with a guest token' do
          include_context 'non-blank guest token'

          context 'with no anonymous orders' do
            include_examples 'order not found'
            include_examples 'idempotent method'
          end

          context 'with anonymous orders' do
            include_context  'setup anonymous order'
            include_examples 'anonymous order returned'
            include_examples 'idempotent method'

            it 'associates the user with the order' do
              expect { apply }.to change { anonymous_order.reload.user }
                .from(nil)
                .to(user)
            end
          end
        end
      end

      context 'with an incomplete order' do
        let!(:order) do
          create(:order_with_totals, user: user)
        end

        context 'with no guest token' do
          include_context  'blank guest token'
          include_examples 'incomplete order returned'
          include_examples 'idempotent method'
        end

        context 'with a guest token' do
          include_context 'non-blank guest token'

          context 'with no anonymous orders' do
            include_examples 'incomplete order returned'
            include_examples 'idempotent method'
          end

          context 'with anonymous orders' do
            include_context  'setup anonymous order'
            include_examples 'incomplete order returned'
            include_examples 'idempotent method'

            it 'merges the anonymous order into the incomplete order' do
              variants = [order, anonymous_order].flat_map(&:variants)
              expect(apply.variants).to eq(variants)
            end
          end
        end
      end
    end

    context 'when the user is not present' do
      let!(:order) { nil }
      let(:user)   { nil }

      # This record should never be returned due to the guard clause
      # that wraps the anonymous order lookup
      let!(:anonymous_order_with_blank_guest_token) do
        create(
          :order_with_totals,
          guest_token: '',
          user:        nil,
          email:       nil
        )
      end

      context 'with no guest token' do
        include_context  'blank guest token'
        include_examples 'order not found'
        include_examples 'idempotent method'
      end

      context 'with a guest token' do
        include_context 'non-blank guest token'

        context 'with no anonymous orders' do
          include_examples 'order not found'
          include_examples 'idempotent method'
        end

        context 'with anonymous orders' do
          include_context  'setup anonymous order'
          include_examples 'anonymous order returned'
          include_examples 'idempotent method'

          it 'does not associate the user with the order' do
            expect { apply }.to_not change { anonymous_order.reload.user }
              .from(nil)
          end
        end
      end
    end
  end

  describe '#cart_order' do
    def apply
      controller.cart_order
    end

    before do
      allow(controller).to receive(:current_order).and_return(current_order)
    end

    context 'current order is found' do
      let(:current_order) { order }

      it 'returns the current order' do
        expect(apply).to be(current_order)
      end

      include_examples 'idempotent method'
    end

    context 'current order is not found' do
      let(:current_order) { nil }

      let(:new_order) do
        build(
          :order,
          bill_address:    nil,
          ship_address:    nil,
          email:           nil,
          currency:        'USD',
          user:            user,
          created_by:      user,
          last_ip_address: '0.0.0.0'
        )
      end

      it 'initializes a new order' do
        order = apply
        expect(order).to be_kind_of(Spree::Order)
        expect(order.attributes).to eql(new_order.attributes)
      end

      include_examples 'idempotent method'
    end
  end

  describe '#associate_user' do
    def apply
      controller.associate_user
    end

    before do
      allow(controller).to receive_messages(current_order: order)
    end

    context 'the current user is nil' do
      let(:user)  { nil                                   }
      let(:order) { create(:order, user: nil, email: nil) }

      it 'does not call Spree::Order#associate_user! method' do
        expect(order).to_not receive(:associate_user!)
        apply
      end
    end

    context 'current order is nil' do
      let(:order) { nil }

      it 'does not call Spree::Order#associate_user! method' do
        expect_any_instance_of(Spree::Order).to_not receive(:associate_user!)
        apply
      end
    end

    context 'when the order user is blank' do
      before do
        order.user = nil
      end

      it 'calls Spree::Order#associate_user! method' do
        expect(order).to receive(:associate_user!).with(user)
        apply
      end
    end

    context 'when the order email is blank' do
      before do
        order.email = nil
      end

      it 'calls Spree::Order#associate_user! method' do
        expect(order).to receive(:associate_user!).with(user)
        apply
      end
    end

    context 'when the order user and email are not blank' do
      it 'does not call Spree::Order#associate_user! method' do
        expect(order).to_not receive(:associate_user!)
        apply
      end
    end
  end

  describe '#set_current_order' do
    def apply
      controller.set_current_order
    end

    context 'with a user' do
      before do
        allow(controller).to receive_messages(current_order: order)
      end

      it 'initializes the current order' do
        expect(controller).to receive_messages(current_order: order)
        apply
      end

      it 'returns the current order' do
        expect(apply).to be(order)
      end
    end

    context 'without a user' do
      let(:user) { nil }

      it 'does not initialize the current order' do
        expect(controller).to_not receive(:current_order)
        apply
      end

      it 'returns nil' do
        expect(apply).to be(nil)
      end
    end
  end

  describe '#current_currency' do
    it 'returns current currency' do
      expect(controller.current_currency).to eql('USD')
    end
  end

  describe '#ip_address' do
    it 'returns remote ip' do
      expect(controller.ip_address).to eql(request.remote_ip)
    end
  end
end
