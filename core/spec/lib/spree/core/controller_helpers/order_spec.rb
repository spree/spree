require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Order
end

describe Spree::Core::ControllerHelpers::Order, type: :controller do
  controller(FakesController) {}

  let(:user)                { create(:user)              }
  let(:order)               { create(:order, user: user) }
  let(:request_guest_token) { nil                        }

  before do
    allow(controller).to receive_messages(
      try_spree_current_user: user,
      cookies:                double('cookies', signed: { guest_token: request_guest_token })
    )
  end

  shared_examples_for 'returning order' do
    # Normally these expectations should be broken up in different blocks.
    # Sadly this spec touches the DB for each block to make this efficient enough
    # for mutaiton testing we need to be a bit more coarse grained right now.
    #
    # Next passes might turn this into *real* unit tests that do not touch the DB anymore.
    it 'returns idempotent order with expected attributes' do
      order = apply
      expect(order.currency).to eql(controller.current_currency)
      expect(order.last_ip_address).to eql(controller.ip_address)
      expect(order.user).to eql(user)
      expect(order.created_by).to eql(expected_created_by)
      expect(apply).to be(order)
    end
  end

  shared_examples_for 'returning expected order' do
    it 'returns expected order' do
      expect(apply).to eql(expected_order)
    end

    include_examples 'returning order'
  end

  shared_examples_for 'lock cannot be aquired' do
    context 'when lock cannot be aquired' do
      context 'because lock is not available' do
        before do
          expect(collection).to receive(:lock)
            .with(true)
            .ordered
            .and_raise(ActiveRecord::StatementInvalid.new('PG::LockNotAvailable: ERROR: details'))
        end

        it 'raises busy order exception' do
          expect { apply }.to raise_error(Spree::Order::OrderBusyError)
        end
      end

      context 'because of unrelated exception' do
        let(:unrelated_exception) { ActiveRecord::StatementInvalid.new('generic other error') }

        before do
          expect(collection).to receive(:lock)
            .with(true)
            .ordered
            .and_raise(unrelated_exception)
        end

        it 'raises the unrelated exception' do
          expect { apply }.to raise_error(unrelated_exception)
        end
      end
    end
  end

  shared_examples_for 'locks the order by token/user' do
    let(:collection) { double('Collection') }

    before do
      expect(Spree::Order).to receive(:incomplete)
        .ordered
        .and_return(collection)
      expect(collection).to receive(:includes)
        .with(:all_adjustments)
        .ordered
        .and_return(collection)
    end

    context 'when lock can be aquired immediately' do
      before do
        expect(collection).to receive(:lock)
          .with(true)
          .ordered
          .and_return(collection)

        expect(collection).to receive(:find_by)
          .with(currency: 'USD', guest_token: request_guest_token, user_id: user.try(:id))
          .ordered
          .and_return(order)
      end

      include_examples 'returning expected order'
    end

    include_examples 'lock cannot be aquired'
  end

  shared_examples_for 'locks the last incomplete order' do
    let(:collection) { double('Collection') }

    before do
      expect(user).to receive(:incomplete_spree_orders)
        .ordered
        .and_return(collection)
    end

    context 'when lock can be aquired immediately' do
      before do
        expect(collection).to receive(:lock)
          .with(true)
          .ordered
          .and_return(collection)

        expect(collection).to receive(:first)
          .and_return(order)
      end

      include_examples 'returning expected order'
    end

    include_examples 'lock cannot be aquired'
  end

  shared_examples_for 'order lookup' do
    let(:expected_created_by) { user }

    context 'whithout user' do
      let(:user)  { nil                  }
      let(:order) { Spree::Order.create! }

      context 'with matching guest token on order' do
        let(:request_guest_token) { order.guest_token }
        let(:expected_order)      { order             }

        include_examples 'locks the order by token/user'
      end

      context 'without matching guest token' do
        include_examples 'order was NOT found'
      end
    end

    context 'with user' do
      context 'with matching guest token' do
        # Preference is guest token based, even when a more recent order exists.
        before do
          order
          create(:order, user: user)
        end

        let(:request_guest_token) { order.guest_token }
        let(:expected_order)      { order             }

        include_examples 'locks the order by token/user'
      end

      context 'and order created by other user is returned' do
        let(:other_user)          { create(:user)                                      }
        let!(:order)              { create(:order, user: user, created_by: other_user) }
        let(:expected_order)      { order                                              }
        let(:expected_created_by) { other_user                                         }

        include_examples 'locks the last incomplete order'
      end

      context 'without matching guest token' do
        context 'and order in history exists' do
          let(:expected_order) { order }

          before { order }

          include_examples 'locks the last incomplete order'
        end

        context 'and incomplete order in history does NOT exist' do
          include_examples 'order was NOT found'
        end
      end
    end
  end

  describe '#current_order' do
    def apply
      controller.current_order
    end

    shared_examples_for 'order was NOT found' do
      it 'returns idempotent nil' do
        expect(apply).to be(nil)
        expect(Spree::Order).to_not receive(:incomplete)
        expect(apply).to be(nil)
      end
    end

    include_examples 'order lookup'
  end

  describe '#cart_order' do
    def apply
      controller.cart_order
    end

    shared_examples_for 'order was NOT found' do
      include_examples 'returning order'
    end

    include_examples 'order lookup'
  end

  describe '#associate_user' do
    def apply
      controller.associate_user
    end

    before do
      allow(controller).to receive_messages(current_order: order)
    end

    context 'current order is nil' do
      let(:order) { nil }

      it 'does not call Spree::Order#associate_user! method' do
        expect(order).to_not receive(:associate_user!)
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

    before do
      allow(controller).to receive_messages(current_order: order)
    end

    context 'with user and current order' do
      let!(:order_a) { create(:order, user: user)                         }
      let!(:order_b) { create(:order, user: user)                         }
      let!(:order_c) { create(:order, user: user, completed_at: Time.now) }

      # This chain of expectations asserts the record gets locked.
      # There is no other known in-memory way since AR does not track
      # if a record was loaded under lock or not.
      it 'locks the incomplete orders' do
        collection = double('collection')
        expect(user).to receive(:incomplete_spree_orders).ordered.and_return(collection)
        expect(collection).to receive(:lock).ordered.and_return(collection)
        expect(collection).to receive(:where).ordered.and_return(collection)
        expect(collection).to receive(:not).ordered.with(id: order).and_return([order_b, order_a])
        expect(order).to receive(:merge!).ordered.with(order_b)
        expect(order).to receive(:merge!).ordered.with(order_a)
        apply
      end

      it 'merges incomplete orders from history into current one' do
        expect(order).to receive(:merge!).ordered.with(order_b)
        expect(order).to receive(:merge!).ordered.with(order_a)
        apply
      end
    end

    context 'without user' do
      let(:user)  { nil            }
      let(:order) { create(:order) }

      it 'returns nil' do
        expect(apply).to be(nil)
      end
    end

    context 'without current order' do
      let(:order) { nil }

      it 'returns nil' do
        expect(apply).to be(nil)
      end
    end
  end

  describe '#current_currency' do
    it 'returns current currency' do
      Spree::Config[:currency] = 'USD'
      expect(controller.current_currency).to eql('USD')
    end
  end

  describe '#ip_address' do
    it 'returns remote ip' do
      expect(controller.ip_address).to eql(request.remote_ip)
    end
  end
end
