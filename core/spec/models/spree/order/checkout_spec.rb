require 'spec_helper'
require 'spree/testing_support/order_walkthrough'

describe Spree::Order, type: :model do
  let(:order) { Spree::Order.new }

  before { create(:store) }

  def assert_state_changed(order, from, to)
    state_change_exists = order.state_changes.where(previous_state: from, next_state: to).exists?
    assert state_change_exists, "Expected order to transition from #{from} to #{to}, but didn't."
  end

  context 'with default state machine' do
    let(:transitions) do
      [
        { address: :delivery },
        { delivery: :payment },
        { payment: :confirm },
        { confirm: :complete },
        { payment: :complete },
        { delivery: :complete }
      ]
    end

    it 'has the following transitions' do
      transitions.each do |transition|
        transition = Spree::Order.find_transition(from: transition.keys.first, to: transition.values.first)
        expect(transition).not_to be_nil
      end
    end

    it 'does not have a transition from delivery to confirm' do
      transition = Spree::Order.find_transition(from: :delivery, to: :confirm)
      expect(transition).to be_nil
    end

    it '.find_transition when contract was broken' do
      expect(Spree::Order.find_transition(foo: :bar, baz: :dog)).to be_falsey
    end

    it '.remove_transition' do
      options = { from: transitions.first.keys.first, to: transitions.first.values.first }
      expect(Spree::Order).to receive_messages(
        removed_transitions:    [],
        next_event_transitions: transitions.dup
      )
      expect(Spree::Order.remove_transition(options)).to be_truthy
      expect(Spree::Order.removed_transitions).to eql([options])
      expect(Spree::Order.next_event_transitions).not_to include(transitions.first)
    end

    it '.remove_transition when contract was broken' do
      expect(Spree::Order.remove_transition(nil)).to be_falsey
    end

    it 'always return integer on checkout_step_index' do
      expect(order.checkout_step_index('imnotthere')).to be_a Integer
      expect(order.checkout_step_index('delivery')).to be > 0
    end

    it 'passes delivery state when transitioning from address over delivery to payment' do
      allow(order).to receive_messages payment_required?: true
      order.state = 'address'
      expect(order.passed_checkout_step?('delivery')).to be false
      order.state = 'delivery'
      expect(order.passed_checkout_step?('delivery')).to be false
      order.state = 'payment'
      expect(order.passed_checkout_step?('delivery')).to be true
    end

    context '#checkout_steps' do
      context 'when confirmation not required' do
        before do
          allow(order).to receive_messages confirmation_required?: false
          allow(order).to receive_messages payment_required?: true
        end

        specify do
          expect(order.checkout_steps).to eq(%w(address delivery payment complete))
        end
      end

      context 'when confirmation required' do
        before do
          allow(order).to receive_messages confirmation_required?: true
          allow(order).to receive_messages payment_required?: true
        end

        specify do
          expect(order.checkout_steps).to eq(%w(address delivery payment confirm complete))
        end
      end

      context 'when payment not required' do
        before { allow(order).to receive_messages payment_required?: false }
        specify do
          expect(order.checkout_steps).to eq(%w(address delivery complete))
        end
      end

      context 'when payment required' do
        before { allow(order).to receive_messages payment_required?: true }
        specify do
          expect(order.checkout_steps).to eq(%w(address delivery payment complete))
        end
      end
    end

    it 'starts out at cart' do
      expect(order.state).to eq('cart')
    end

    context 'to address' do
      before do
        order.email = 'user@example.com'
        order.save!
      end

      context 'with a line item' do
        before do
          order.line_items << FactoryBot.create(:line_item)
        end

        it 'transitions to address' do
          order.next!
          assert_state_changed(order, 'cart', 'address')
          expect(order.state).to eq('address')
        end

        it "doesn't raise an error if the default address is invalid" do
          order.user = mock_model(Spree::LegacyUser, ship_address: Spree::Address.new, bill_address: Spree::Address.new)
          expect { order.next! }.not_to raise_error
        end

        context 'with default addresses' do
          let(:default_address) { FactoryBot.create(:address) }

          before do
            order.user = FactoryBot.create(:user, "#{address_kind}_address" => default_address)
            order.next!
            order.reload
          end

          shared_examples 'it cloned the default address' do
            it do
              default_attributes = default_address.attributes
              order_attributes = order.send("#{address_kind}_address".to_sym).try(:attributes) || {}

              expect(order_attributes.except('id', 'created_at', 'updated_at')).to eql(default_attributes.except('id', 'created_at', 'updated_at'))
            end
          end

          it_behaves_like 'it cloned the default address' do
            let(:address_kind) { 'ship' }
          end

          it_behaves_like 'it cloned the default address' do
            let(:address_kind) { 'bill' }
          end
        end
      end

      it 'cannot transition to address without any line items' do
        expect(order.line_items).to be_blank
        expect { order.next! }.to raise_error(StateMachines::InvalidTransition, /#{Spree.t(:there_are_no_items_for_this_order)}/)
      end
    end

    context 'from address' do
      before do
        order.state = 'address'
        allow(order).to receive(:has_available_payment)
        create(:shipment, order: order)
        order.email = 'user@example.com'
        order.save!
      end

      it 'updates totals' do
        allow(order).to receive_messages(ensure_available_shipping_rates: true)
        line_item = FactoryBot.create(:line_item, price: 10, adjustment_total: 10)
        line_item.variant.update_attributes!(price: 10)
        order.line_items << line_item
        tax_rate = create(:tax_rate, tax_category: line_item.tax_category, amount: 0.05)
        allow(Spree::TaxRate).to receive_messages match: [tax_rate]
        FactoryBot.create(:tax_adjustment, adjustable: line_item, source: tax_rate, order: order)
        order.email = 'user@example.com'
        order.next!
        expect(order.adjustment_total).to eq(0.5)
        expect(order.additional_tax_total).to eq(0.5)
        expect(order.included_tax_total).to eq(0)
        expect(order.total).to eq(10.5)
      end

      it 'updates prices' do
        allow(order).to receive_messages(ensure_available_shipping_rates: true)
        line_item = FactoryBot.create(:line_item, price: 10, adjustment_total: 10)
        line_item.variant.update_attributes!(price: 20)
        order.line_items << line_item
        tax_rate = create :tax_rate,
                          included_in_price: true,
                          tax_category: line_item.tax_category,
                          amount: 0.05
        allow(Spree::TaxRate).to receive_messages(match: [tax_rate])
        FactoryBot.create :tax_adjustment,
                           adjustable: line_item,
                           source: tax_rate,
                           order: order
        order.email = 'user@example.com'
        order.next!
        expect(order.adjustment_total).to eq(0)
        expect(order.additional_tax_total).to eq(0)
        expect(order.included_tax_total).to eq(0.95)
        expect(order.total).to eq(20)
      end

      it 'transitions to delivery' do
        allow(order).to receive_messages(ensure_available_shipping_rates: true)
        order.next!
        assert_state_changed(order, 'address', 'delivery')
        expect(order.state).to eq('delivery')
      end

      it 'does not call persist_order_address if there is no address on the order' do
        # otherwise, it will crash
        allow(order).to receive_messages(ensure_available_shipping_rates: true)

        order.user = FactoryBot.create(:user)
        order.save!

        expect(order.user).not_to receive(:persist_order_address).with(order)
        order.next!
      end

      it "calls persist_order_address on the order's user" do
        allow(order).to receive_messages(ensure_available_shipping_rates: true)

        order.user = FactoryBot.create(:user)
        order.ship_address = FactoryBot.create(:address)
        order.bill_address = FactoryBot.create(:address)
        order.save!

        expect(order.user).to receive(:persist_order_address).with(order)
        order.next!
      end

      it "does not call persist_order_address on the order's user for a temporary address" do
        allow(order).to receive_messages(ensure_available_shipping_rates: true)

        order.user = FactoryBot.create(:user)
        order.temporary_address = true
        order.save!

        expect(order.user).not_to receive(:persist_order_address)
        order.next!
      end

      context 'cannot transition to delivery' do
        context 'with an existing shipment' do
          before do
            line_item = FactoryBot.create(:line_item, price: 10)
            order.line_items << line_item
          end

          context 'if there are no shipping rates for any shipment' do
            it 'raises an InvalidTransitionError' do
              transition = -> { order.next! }
              expect(transition).to raise_error(StateMachines::InvalidTransition, /#{Spree.t(:items_cannot_be_shipped)}/)
            end

            it 'deletes all the shipments' do
              order.next
              expect(order.shipments).to be_empty
            end
          end
        end
      end
    end

    context 'to delivery' do
      context 'when order has default selected_shipping_rate_id' do
        let(:shipment) { create(:shipment, order: order) }
        let(:shipping_method) { create(:shipping_method) }
        let(:shipping_rate) do
          [
            Spree::ShippingRate.create!(shipping_method: shipping_method, cost: 10.00, shipment: shipment)
          ]
        end

        before do
          order.state = 'address'
          shipment.selected_shipping_rate_id = shipping_rate.first.id
          order.email = 'user@example.com'
          order.save!

          allow(order).to receive(:has_available_payment)
          allow(order).to receive(:create_proposed_shipments)
          allow(order).to receive(:ensure_available_shipping_rates).and_return(true)
        end

        it 'invokes set_shipment_cost' do
          expect(order).to receive(:set_shipments_cost)
          order.next!
        end

        it 'updates shipment_total' do
          expect { order.next! }.to change(order, :shipment_total).by(10.00)
        end
      end
    end

    context 'from delivery' do
      before do
        order.state = 'delivery'
        allow(order).to receive(:apply_free_shipping_promotions)
      end

      it 'attempts to apply free shipping promotions' do
        expect(order).to receive(:apply_free_shipping_promotions)
        order.next!
      end

      context 'with payment required' do
        before do
          allow(order).to receive_messages payment_required?: true
        end

        it 'transitions to payment' do
          expect(order).to receive(:set_shipments_cost)
          order.next!
          assert_state_changed(order, 'delivery', 'payment')
          expect(order.state).to eq('payment')
        end
      end

      context 'without payment required' do
        before do
          allow(order).to receive_messages payment_required?: false
        end

        it 'transitions to complete' do
          order.next!
          expect(order.state).to eq('complete')
        end
      end

      context 'correctly determining payment required based on shipping information' do
        let(:shipment) do
          FactoryBot.create(:shipment)
        end

        before do
          # Needs to be set here because we're working with a persisted order object
          order.email = 'test@example.com'
          order.save!
          order.shipments << shipment
        end

        context 'with a shipment that has a price' do
          before do
            shipment.shipping_rates.first.update_column(:cost, 10)
            order.set_shipments_cost
          end

          it 'transitions to payment' do
            order.next!
            expect(order.state).to eq('payment')
          end
        end

        context 'with a shipment that is free' do
          before do
            shipment.shipping_rates.first.update_column(:cost, 0)
            order.set_shipments_cost
          end

          it 'skips payment, transitions to complete' do
            order.next!
            expect(order.state).to eq('complete')
          end
        end
      end
    end

    context 'from payment' do
      before do
        order.state = 'payment'
      end

      context 'with confirmation required' do
        before do
          allow(order).to receive_messages confirmation_required?: true
        end

        it 'transitions to confirm' do
          order.next!
          assert_state_changed(order, 'payment', 'confirm')
          expect(order.state).to eq('confirm')
        end
      end

      context 'without confirmation required' do
        before do
          order.email = 'spree@example.com'
          allow(order).to receive_messages confirmation_required?: false
          allow(order).to receive_messages payment_required?: true
          order.payments << FactoryBot.create(:payment, state: payment_state, order: order)
        end

        context 'when there is at least one valid payment' do
          let(:payment_state) { 'checkout' }

          context 'line_items are in stock' do
            before do
              expect(order).to receive(:process_payments!).once.and_return(true)
            end

            it 'transitions to complete' do
              order.next!
              assert_state_changed(order, 'payment', 'complete')
              expect(order.state).to eq('complete')
            end
          end

          context 'line_items are not in stock' do
            before do
              expect(order).to receive(:ensure_line_items_are_in_stock).once.and_return(false)
            end

            it 'does not receive process_payments!' do
              expect(order).not_to receive(:process_payments!)
              order.next
            end

            it 'does not transition to complete' do
              order.next
              expect(order.state).to eq('payment')
            end
          end
        end

        context 'when there is only an invalid payment' do
          let(:payment_state) { 'failed' }

          it 'raises a StateMachine::InvalidTransition' do
            expect do
              order.next!
            end.to raise_error(StateMachines::InvalidTransition, /#{Spree.t(:no_payment_found)}/)

            expect(order.errors[:base]).to include(Spree.t(:no_payment_found))
          end
        end
      end

      # Regression test for #2028
      context 'when payment is not required' do
        before do
          allow(order).to receive_messages payment_required?: false
        end

        it 'does not call process payments' do
          expect(order).not_to receive(:process_payments!)
          order.next!
          assert_state_changed(order, 'payment', 'complete')
          expect(order.state).to eq('complete')
        end
      end
    end
  end

  context 'to complete' do
    before do
      order.state = 'confirm'
      order.save!
    end

    context 'default credit card' do
      before do
        order.user = FactoryBot.create(:user)
        order.email = 'spree@example.org'
        order.payments << FactoryBot.create(:payment)

        # make sure we will actually capture a payment
        allow(order).to receive_messages(payment_required?: true)
        order.line_items << FactoryBot.create(:line_item)
        Spree::OrderUpdater.new(order).update

        order.save!
      end

      it "makes the current credit card a user's default credit card" do
        order.next!
        expect(order.state).to eq 'complete'
        expect(order.user.reload.default_credit_card.try(:id)).to eq(order.credit_cards.first.id)
      end

      it 'does not assign a default credit card if temporary_credit_card is set' do
        order.temporary_credit_card = true
        order.next!
        expect(order.user.reload.default_credit_card).to be_nil
      end
    end
  end

  context 'subclassed order' do
    # This causes another test above to fail, but fixing this test should make
    #   the other test pass
    class SubclassedOrder < Spree::Order
      checkout_flow do
        go_to_state :payment
        go_to_state :complete
      end
    end

    skip 'should only call default transitions once when checkout_flow is redefined' do
      order = SubclassedOrder.new
      allow(order).to receive_messages payment_required?: true
      expect(order).to receive(:process_payments!).once
      order.state = 'payment'
      order.next!
      assert_state_changed(order, 'payment', 'complete')
      expect(order.state).to eq('complete')
    end
  end

  context 're-define checkout flow' do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        checkout_flow do
          go_to_state :payment
          go_to_state :complete
        end
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it 'does not keep old event transitions when checkout_flow is redefined' do
      expect(Spree::Order.next_event_transitions).to eq([{ cart: :payment }, { payment: :complete }])
    end

    it 'does not keep old events when checkout_flow is redefined' do
      state_machine = Spree::Order.state_machine
      expect(state_machine.states.any? { |s| s.name == :address }).to be false
      known_states = state_machine.events[:next].branches.map(&:known_states).flatten
      expect(known_states).not_to include(:address)
      expect(known_states).not_to include(:delivery)
      expect(known_states).not_to include(:confirm)
    end
  end

  # Regression test for #3665
  context 'with only a complete step' do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        checkout_flow do
          go_to_state :complete
        end
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it 'does not attempt to process payments' do
      allow(order).to receive_message_chain(:line_items, :present?) { true }
      allow(order).to receive(:ensure_line_items_are_in_stock).and_return(true)
      allow(order).to receive(:ensure_line_item_variants_are_not_discontinued).and_return(true)
      expect(order).not_to receive(:payment_required?)
      expect(order).not_to receive(:process_payments!)
      order.next!
      assert_state_changed(order, 'cart', 'complete')
    end
  end

  context 'insert checkout step' do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        insert_checkout_step :new_step, before: :address
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it 'maintains removed transitions' do
      transition = Spree::Order.find_transition(from: :delivery, to: :confirm)
      expect(transition).to be_nil
    end

    context 'before' do
      before do
        Spree::Order.class_eval do
          insert_checkout_step :before_address, before: :address
        end
      end

      specify do
        order = Spree::Order.new
        expect(order.checkout_steps).to eq(%w(new_step before_address address delivery complete))
      end

      it 'goes through checkout without raising error' do
        expect { OrderWalkthrough.up_to(:complete) }.not_to raise_error
      end
    end

    context 'after' do
      before do
        Spree::Order.class_eval do
          insert_checkout_step :after_address, after: :address
        end
      end

      specify do
        order = Spree::Order.new
        expect(order.checkout_steps).to eq(%w(new_step address after_address delivery complete))
      end

      it 'goes through checkout without raising error' do
        expect { OrderWalkthrough.up_to(:complete) }.not_to raise_error
      end
    end
  end

  context 'remove checkout step' do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        remove_checkout_step :address
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it 'maintains removed transitions' do
      transition = Spree::Order.find_transition(from: :delivery, to: :confirm)
      expect(transition).to be_nil
    end

    specify do
      order = Spree::Order.new
      expect(order.checkout_steps).to eq(%w(delivery complete))
    end
  end

  describe 'update_from_params' do
    let(:permitted_params) { {} }
    let(:params) { {} }

    it 'calls update_atributes without order params' do
      expect(order).to receive(:update_attributes).with({})
      order.update_from_params(params, permitted_params)
    end

    it 'runs the callbacks' do
      expect(order).to receive(:run_callbacks).with(:updating_from_params)
      order.update_from_params(params, permitted_params)
    end

    context 'passing a credit card' do
      let(:permitted_params) do
        Spree::PermittedAttributes.checkout_attributes +
          [payments_attributes: Spree::PermittedAttributes.payment_attributes]
      end

      let(:credit_card) { create(:credit_card, user_id: order.user_id) }

      let(:params) do
        ActionController::Parameters.new(
          order: { payments_attributes: [{ payment_method_id: 1 }], existing_card: credit_card.id },
          cvc_confirm: '737',
          payment_source: {
            '1' => { name: 'Luis Braga',
                     number: '4111 1111 1111 1111',
                     expiry: '06 / 2016',
                     verification_value: '737',
                     cc_type: '' }
          }
        )
      end

      before { order.user_id = 3 }

      it 'sets confirmation value when its available via :cvc_confirm' do
        allow(Spree::CreditCard).to receive_messages find: credit_card
        expect(credit_card).to receive(:verification_value=)
        order.update_from_params(params, permitted_params)
      end

      it 'sets existing card as source for new payment' do
        expect do
          order.update_from_params(params, permitted_params)
        end.to change { Spree::Payment.count }.by(1)

        expect(Spree::Payment.last.source).to eq credit_card
      end

      it 'sets request_env on payment' do
        request_env = { 'USER_AGENT' => 'Firefox' }

        order.update_from_params(params, permitted_params, request_env)
        expect(order.payments[0].request_env).to eq request_env
      end

      it 'dont let users mess with others users cards' do
        credit_card.update_column :user_id, 5

        expect do
          order.update_from_params(params, permitted_params)
        end.to raise_error(Spree.t(:invalid_credit_card))
      end
    end

    context 'has params' do
      let(:permitted_params) { [:good_param] }
      let(:params) { ActionController::Parameters.new(order: { bad_param: 'okay' }) }

      it 'does not let through unpermitted attributes' do
        expect(order).to receive(:update_attributes).with(ActionController::Parameters.new.permit!)
        order.update_from_params(params, permitted_params)
      end

      context 'has existing_card param' do
        let(:permitted_params) do
          Spree::PermittedAttributes.checkout_attributes +
            [payments_attributes: Spree::PermittedAttributes.payment_attributes]
        end
        let(:credit_card) { create(:credit_card, user_id: order.user_id) }
        let(:params) do
          ActionController::Parameters.new(
            order: { payments_attributes: [{ payment_method_id: 1 }], existing_card: credit_card.id }
          )
        end

        before do
          Dummy::Application.config.action_controller.action_on_unpermitted_parameters = :raise
          order.user_id = 3
        end

        after do
          Dummy::Application.config.action_controller.action_on_unpermitted_parameters = :log
        end

        it 'does not attempt to permit existing_card' do
          expect do
            order.update_from_params(params, permitted_params)
          end.not_to raise_error
        end
      end

      context 'has allowed params' do
        let(:params) { ActionController::Parameters.new(order: { good_param: 'okay' }) }

        it 'accepts permitted attributes' do
          expect(order).to receive(:assign_attributes).with(ActionController::Parameters.new('good_param' => 'okay').permit!)
          order.update_from_params(params, permitted_params)
        end
      end
    end
  end
end
