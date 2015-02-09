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

  describe '#simple_current_order' do
    let(:request_guest_token) { order.guest_token }

    it 'returns an empty order' do
      expect(controller.simple_current_order.item_count).to eql(0)
    end

    it 'returns Spree::Order instance' do
      expect(controller.simple_current_order).to eql(order)
    end
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

  shared_examples_for 'locks the order by token/user' do
    # This chain of expectations asserts the record gets locked.
    # There is no other known in-memory way since AR does not track
    # if a record was loaded under lock or not.
    it 'locks the order' do
      collection = double('Collection')

      expect(Spree::Order).to receive(:incomplete)
        .ordered
        .and_return(collection)

      expect(collection).to receive(:includes)
        .with(:all_adjustments)
        .ordered
        .and_return(collection)

      expect(collection).to receive(:lock)
        .with(true)
        .ordered
        .and_return(collection)

      expect(collection).to receive(:find_by)
        .with(currency: 'USD', guest_token: request_guest_token, user_id: user.try(:id))
        .ordered
        .and_return(order)

      apply
    end
  end

  shared_examples_for 'locks the last incomplete order' do
    # This chain of expectations asserts the record gets locked.
    # There is no other known in-memory way since AR does not track
    # if a record was loaded under lock or not.
    it 'locks the order' do
      collection = double('Collection')

      expect(user).to receive(:incomplete_spree_orders)
        .ordered
        .and_return(collection)

      expect(collection).to receive(:lock)
        .with(true)
        .ordered
        .and_return(collection)

      expect(collection).to receive(:first)
        .and_return(order)

      apply
    end
  end

  shared_examples_for 'order lookup' do
    let(:expected_created_by) { user }

    context 'whithout user' do
      let(:user)  { nil                  }
      let(:order) { Spree::Order.create! }

      context 'with matching guest token on order' do
        let(:request_guest_token) { order.guest_token }
        let(:expected_order)      { order             }

        include_examples 'returning expected order'
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

        include_examples 'returning expected order'
        include_examples 'locks the order by token/user'
      end

      context 'and order created by other user is returned' do
        let(:other_user)          { create(:user)                                      }
        let!(:order)              { create(:order, user: user, created_by: other_user) }
        let(:expected_order)      { order                                              }
        let(:expected_created_by) { other_user                                         }

        include_examples 'returning expected order'
      end

      context 'without matching guest token' do
        context 'and order in history exists' do
          let(:expected_order) { order }

          before { order }

          include_examples 'returning expected order'
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
    before do
      allow(controller).to receive_messages(current_order: order)
    end

    context 'users email is blank' do
      let(:user) { create(:user, email: '') }

      it 'calls Spree::Order#associate_user! method' do
        expect_any_instance_of(Spree::Order).to receive(:associate_user!)
        controller.associate_user
      end
    end

    context 'user is not blank' do
      it 'does not calls Spree::Order#associate_user! method' do
        expect_any_instance_of(Spree::Order).not_to receive(:associate_user!)
        controller.associate_user
      end
    end
  end

  describe '#set_current_order' do
    let(:incomplete_order) { create(:order, user: user) }

    context 'when current order not equal to users incomplete orders' do
      before do
        allow(controller).to receive_messages(current_order: order)
      end

      it 'calls Spree::Order#merge! method' do
        expect(order).to receive(:merge!).with(incomplete_order, user)
        controller.set_current_order
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
