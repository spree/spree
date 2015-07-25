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
    let(:relation) { double('relation').as_null_object }

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

      context 'locking behaviour' do
        before do
          expect(user).to receive(:orders).and_return(relation)

          expect(relation).to receive(:where).with(currency: 'USD')
            .and_return(relation)
        end

        it 'locks the order' do
          expect(apply).to be(relation)
          expect(relation).to have_received(:lock).with(no_args)
        end
      end
    end

    shared_examples_for 'anonymous order returned' do
      include_examples 'order found'

      it 'returns the anonymous order' do
        expect(apply).to eql(anonymous_order)
      end

      context 'locking behaviour' do
        before do
          stub_const('Spree::Order', relation)

          expect(relation).to receive(:where)
            .with(guest_token: guest_token, user_id: nil)
            .and_return(relation)

          expect(relation).to receive(:where).with(currency: 'USD')
            .and_return(relation)
        end

        it 'locks the order' do
          expect(apply).to be(relation)
          expect(relation).to have_received(:lock).with(no_args)
        end
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

          it 'does not query for anonymous users' do
            stub_const('Spree::Order', relation)
            expect(relation).to_not receive(:where)
              .with(guest_token: nil, user_id: nil)
            apply
          end
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
      let(:current_order) { nil      }
      let(:guest_token)   { 'ABC123' }

      let(:new_order) do
        build(
          :order,
          bill_address:    nil,
          ship_address:    nil,
          email:           nil,
          currency:        'USD',
          user:            user,
          created_by:      user,
          store:           nil,
          last_ip_address: '0.0.0.0',
          guest_token:     guest_token
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
    before do
      allow(controller).to receive_messages(current_order: order)
    end
    context "user's email is blank" do
      let(:user) { create(:user, email: '') }
      it 'calls Spree::Order#associate_user! method' do
        expect_any_instance_of(Spree::Order).to receive(:associate_user!)
        controller.associate_user
      end
    end
    context "user isn't blank" do
      it 'does not calls Spree::Order#associate_user! method' do
        expect_any_instance_of(Spree::Order).not_to receive(:associate_user!)
        controller.associate_user
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
