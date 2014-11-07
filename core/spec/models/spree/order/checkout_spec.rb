require 'spec_helper'
require 'spree/testing_support/order_walkthrough'

describe Spree::Order do
  let(:order) { Spree::Order.new }

  def assert_state_changed(order, from, to)
    state_change_exists = order.state_changes.where(:previous_state => from, :next_state => to).exists?
    assert state_change_exists, "Expected order to transition from #{from} to #{to}, but didn't."
  end

  context "with default state machine" do
    let(:transitions) do
      [
        { :address => :delivery },
        { :delivery => :payment },
        { :payment => :confirm },
        { :confirm => :complete },
        { :payment => :complete },
        { :delivery => :complete }
      ]
    end

    it "has the following transitions" do
      transitions.each do |transition|
        transition = Spree::Order.find_transition(:from => transition.keys.first, :to => transition.values.first)
        transition.should_not be_nil
      end
    end

    it "does not have a transition from delivery to confirm" do
      transition = Spree::Order.find_transition(:from => :delivery, :to => :confirm)
      transition.should be_nil
    end

    it '.find_transition when contract was broken' do
      Spree::Order.find_transition({foo: :bar, baz: :dog}).should be_false
    end

    it '.remove_transition' do
      options = {:from => transitions.first.keys.first, :to => transitions.first.values.first}
      Spree::Order.stub(:next_event_transition).and_return([options])
      Spree::Order.remove_transition(options).should be_true
    end

    it '.remove_transition when contract was broken' do
      Spree::Order.remove_transition(nil).should be_false
    end

    context "#checkout_steps" do
      context "when confirmation not required" do
        before do
          order.stub :confirmation_required? => false
          order.stub :payment_required? => true
        end

        specify do
          order.checkout_steps.should == %w(address delivery payment complete)
        end
      end

      context "when confirmation required" do
        before do
          order.stub :confirmation_required? => true
          order.stub :payment_required? => true
        end

        specify do
          order.checkout_steps.should == %w(address delivery payment confirm complete)
        end
      end

      context "when payment not required" do
        before { order.stub :payment_required? => false }
        specify do
          order.checkout_steps.should == %w(address delivery complete)
        end
      end

      context "when payment required" do
        before { order.stub :payment_required? => true }
        specify do
          order.checkout_steps.should == %w(address delivery payment complete)
        end
      end
    end

    it "starts out at cart" do
      order.state.should == "cart"
    end

    context "to address" do
      before do
        order.email = "user@example.com"
        order.save!
      end

      context "with a line item" do
        before do
          order.line_items << FactoryGirl.create(:line_item)
        end

        it "transitions to address" do
          order.next!
          assert_state_changed(order, 'cart', 'address')
          order.state.should == "address"
        end

        it "doesn't raise an error if the default address is invalid" do
          order.user = mock_model(Spree::LegacyUser, ship_address: Spree::Address.new, bill_address: Spree::Address.new)
          expect { order.next! }.to_not raise_error
        end

        context "with default addresses" do
          let(:default_address) { FactoryGirl.create(:address) }

          before do
            order.user = FactoryGirl.create(:user, "#{address_kind}_address" => default_address)
            order.next!
            order.reload
          end

          shared_examples "it cloned the default address" do
            it do
              default_attributes = default_address.attributes
              order_attributes = order.send("#{address_kind}_address".to_sym).try(:attributes) || {}

              order_attributes.except('id', 'created_at', 'updated_at').should eql(default_attributes.except('id', 'created_at', 'updated_at'))
            end
          end

          it_behaves_like "it cloned the default address" do
            let(:address_kind) { 'ship' }
          end

          it_behaves_like "it cloned the default address" do
            let(:address_kind) { 'bill' }
          end
        end
      end

      it "cannot transition to address without any line items" do
        order.line_items.should be_blank
        lambda { order.next! }.should raise_error(StateMachine::InvalidTransition, /#{Spree.t(:there_are_no_items_for_this_order)}/)
      end
    end

    context "from address" do
      before do
        order.state = 'address'
        order.stub(:has_available_payment)
        shipment = FactoryGirl.create(:shipment, :order => order)
        order.email = "user@example.com"
        order.save!
      end

      it "updates totals" do
        order.stub(:ensure_available_shipping_rates => true)
        line_item = FactoryGirl.create(:line_item, :price => 10, :adjustment_total => 10)
        order.line_items << line_item
        tax_rate = create(:tax_rate, :tax_category => line_item.tax_category, :amount => 0.05)
        Spree::TaxRate.stub :match => [tax_rate]
        FactoryGirl.create(:tax_adjustment, :adjustable => line_item, :source => tax_rate)
        order.email = "user@example.com"
        order.next!
        order.adjustment_total.should == 0.5
        order.additional_tax_total.should == 0.5
        order.included_tax_total.should == 0
        order.total.should == 10.5
      end

      it "transitions to delivery" do
        order.stub(:ensure_available_shipping_rates => true)
        order.next!
        assert_state_changed(order, 'address', 'delivery')
        order.state.should == "delivery"
      end

      it "does not call persist_order_address if there is no address on the order" do
        # otherwise, it will crash
        order.stub(:ensure_available_shipping_rates => true)

        order.user = FactoryGirl.create(:user)
        order.save!

        expect(order.user).to_not receive(:persist_order_address).with(order)
        order.next!
      end

      it "calls persist_order_address on the order's user" do
        order.stub(:ensure_available_shipping_rates => true)

        order.user = FactoryGirl.create(:user)
        order.ship_address = FactoryGirl.create(:address)
        order.bill_address = FactoryGirl.create(:address)
        order.save!

        expect(order.user).to receive(:persist_order_address).with(order)
        order.next!
      end

      it "does not call persist_order_address on the order's user for a temporary address" do
        order.stub(:ensure_available_shipping_rates => true)

        order.user = FactoryGirl.create(:user)
        order.temporary_address = true
        order.save!

        expect(order.user).to_not receive(:persist_order_address)
        order.next!
      end

      context "cannot transition to delivery" do
        context "with an existing shipment" do
          before do
            line_item = FactoryGirl.create(:line_item, :price => 10)
            order.line_items << line_item
          end

          context "if there are no shipping rates for any shipment" do
            it "raises an InvalidTransitionError" do
              transition = lambda { order.next! }
              transition.should raise_error(StateMachine::InvalidTransition, /#{Spree.t(:items_cannot_be_shipped)}/)
            end

            it "deletes all the shipments" do
              order.next
              order.shipments.should be_empty
            end
          end
        end
      end
    end

    context "to delivery" do
      context 'when order has default selected_shipping_rate_id' do
        let(:shipment) { create(:shipment, order: order) }
        let(:shipping_method) { create(:shipping_method) }
        let(:shipping_rate) { [
          Spree::ShippingRate.create!(shipping_method: shipping_method, cost: 10.00, shipment: shipment)
        ] }

        before do
          order.state = 'address'
          shipment.selected_shipping_rate_id = shipping_rate.first.id
          order.email = "user@example.com"
          order.save!

          allow(order).to receive(:has_available_payment)
          allow(order).to receive(:create_proposed_shipments)
          allow(order).to receive(:ensure_available_shipping_rates) { true }
        end

        it 'should invoke set_shipment_cost' do
          expect(order).to receive(:set_shipments_cost)
          order.next!
        end

        it 'should update shipment_total' do
          expect { order.next! }.to change{ order.shipment_total }.by(10.00)
        end
      end
    end

    context "from delivery" do
      before do
        order.state = 'delivery'
        order.stub(:apply_free_shipping_promotions)
      end

      it "attempts to apply free shipping promotions" do
        order.should_receive(:apply_free_shipping_promotions)
        order.next!
      end

      context "with payment required" do
        before do
          order.stub :payment_required? => true
        end

        it "transitions to payment" do
          order.should_receive(:set_shipments_cost)
          order.next!
          assert_state_changed(order, 'delivery', 'payment')
          order.state.should == 'payment'
        end
      end

      context "without payment required" do
        before do
          order.stub :payment_required? => false
        end

        it "transitions to complete" do
          order.next!
          order.state.should == "complete"
        end
      end

      context "correctly determining payment required based on shipping information" do
        let(:shipment) do
          FactoryGirl.create(:shipment)
        end

        before do
          # Needs to be set here because we're working with a persisted order object
          order.email = "test@example.com"
          order.save!
          order.shipments << shipment
        end

        context "with a shipment that has a price" do
          before do
            shipment.shipping_rates.first.update_column(:cost, 10)
            order.set_shipments_cost
          end

          it "transitions to payment" do
            order.next!
            order.state.should == "payment"
          end
        end

        context "with a shipment that is free" do
          before do
            shipment.shipping_rates.first.update_column(:cost, 0)
            order.set_shipments_cost
          end

          it "skips payment, transitions to complete" do
            order.next!
            order.state.should == "complete"
          end
        end
      end
    end

    context "from payment" do
      before do
        order.state = 'payment'
      end

      context "with confirmation required" do
        before do
          order.stub :confirmation_required? => true
        end

        it "transitions to confirm" do
          order.next!
          assert_state_changed(order, 'payment', 'confirm')
          order.state.should == "confirm"
        end
      end

      context "without confirmation required" do
        before do
          order.email = "spree@example.com"
          order.stub :confirmation_required? => false
          order.stub :payment_required? => true
          order.payments << FactoryGirl.create(:payment, state: payment_state, order: order)
        end

        context 'when there is at least one valid payment' do
          let(:payment_state) { 'checkout' }

          before do
            expect(order).to receive(:process_payments!).once { true }
          end

          it "transitions to complete" do
            order.next!
            assert_state_changed(order, 'payment', 'complete')
            expect(order.state).to eq('complete')
          end
        end

        context 'when there is only an invalid payment' do
          let(:payment_state) { 'failed' }

          it "raises a StateMachine::InvalidTransition" do
            expect {
              order.next!
            }.to raise_error(StateMachine::InvalidTransition, /#{Spree.t(:no_payment_found)}/)

            expect(order.errors[:base]).to include(Spree.t(:no_payment_found))
          end
        end
      end

      # Regression test for #2028
      context "when payment is not required" do
        before do
          order.stub :payment_required? => false
        end

        it "does not call process payments" do
          order.should_not_receive(:process_payments!)
          order.next!
          assert_state_changed(order, 'payment', 'complete')
          order.state.should == "complete"
        end
      end
    end
  end

  context "subclassed order" do
    # This causes another test above to fail, but fixing this test should make
    #   the other test pass
    class SubclassedOrder < Spree::Order
      checkout_flow do
        go_to_state :payment
        go_to_state :complete
      end
    end

    pending "should only call default transitions once when checkout_flow is redefined" do
      order = SubclassedOrder.new
      order.stub :payment_required? => true
      order.should_receive(:process_payments!).once
      order.state = "payment"
      order.next!
      assert_state_changed(order, 'payment', 'complete')
      order.state.should == "complete"
    end
  end

  context "re-define checkout flow" do
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

    it "should not keep old event transitions when checkout_flow is redefined" do
      Spree::Order.next_event_transitions.should == [{:cart=>:payment}, {:payment=>:complete}]
    end

    it "should not keep old events when checkout_flow is redefined" do
      state_machine = Spree::Order.state_machine
      state_machine.states.any? { |s| s.name == :address }.should be_false
      known_states = state_machine.events[:next].branches.map(&:known_states).flatten
      known_states.should_not include(:address)
      known_states.should_not include(:delivery)
      known_states.should_not include(:confirm)
    end
  end

  # Regression test for #3665
  context "with only a complete step" do
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

    it "does not attempt to process payments" do
      allow(order).to receive_message_chain(:line_items, :present?) { true }
      allow(order).to receive(:ensure_line_items_are_in_stock) { true }
      expect(order).not_to receive(:payment_required?)
      expect(order).not_to receive(:process_payments!)
      order.next!
      assert_state_changed(order, 'cart', 'complete')
    end

  end

  context "insert checkout step" do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        insert_checkout_step :new_step, before: :address
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it "should maintain removed transitions" do
      transition = Spree::Order.find_transition(:from => :delivery, :to => :confirm)
      transition.should be_nil
    end

    context "before" do
      before do
        Spree::Order.class_eval do
          insert_checkout_step :before_address, before: :address
        end
      end

      specify do
        order = Spree::Order.new
        order.checkout_steps.should == %w(new_step before_address address delivery complete)
      end
    end

    context "after" do
      before do
        Spree::Order.class_eval do
          insert_checkout_step :after_address, after: :address
        end
      end

      specify do
        order = Spree::Order.new
        order.checkout_steps.should == %w(new_step address after_address delivery complete)
      end
    end
  end

  context "remove checkout step" do
    before do
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        remove_checkout_step :address
      end
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it "should maintain removed transitions" do
      transition = Spree::Order.find_transition(:from => :delivery, :to => :confirm)
      transition.should be_nil
    end

    specify do
      order = Spree::Order.new
      order.checkout_steps.should == %w(delivery complete)
    end
  end

  describe "payment processing" do
    # Turn off transactional fixtures so that we can test that
    # processing state is persisted.
    self.use_transactional_fixtures = false
    before(:all) { DatabaseCleaner.strategy = :truncation }
    after(:all) do
      DatabaseCleaner.clean
      DatabaseCleaner.strategy = :transaction
    end
    let(:order) { OrderWalkthrough.up_to(:payment) }
    let(:creditcard) { create(:credit_card) }
    let!(:payment_method) { create(:credit_card_payment_method, :environment => 'test') }

    it "does not process payment within transaction" do
      # Make sure we are not already in a transaction
      ActiveRecord::Base.connection.open_transactions.should == 0

      Spree::Payment.any_instance.should_receive(:authorize!) do
        ActiveRecord::Base.connection.open_transactions.should == 0
      end

      order.payments.create!({ :amount => order.outstanding_balance, :payment_method => payment_method, :source => creditcard })
      begin
        order.next!
      rescue
        puts order.errors
      end
    end
  end

  describe 'update_from_params' do
    let(:permitted_params) { {} }
    let(:params) { {} }

    it 'calls update_atributes without order params' do
      order.should_receive(:update_attributes).with({})
      order.update_from_params( params, permitted_params)
    end

    it 'runs the callbacks' do
      order.should_receive(:run_callbacks).with(:updating_from_params)
      order.update_from_params( params, permitted_params)
    end

    context "passing a credit card" do
      let(:permitted_params) do
        Spree::PermittedAttributes.checkout_attributes +
          [payments_attributes: Spree::PermittedAttributes.payment_attributes]
      end

      let(:credit_card) { create(:credit_card, user_id: order.user_id) }

      let(:params) do
        ActionController::Parameters.new(
          order: { payments_attributes: [{payment_method_id: 1}] },
          existing_card: credit_card.id,
          cvc_confirm: "737",
          payment_source: {
            "1" => { name: "Luis Braga",
                     number: "4111 1111 1111 1111",
                     expiry: "06 / 2016",
                     verification_value: "737",
                     cc_type: "" }
          }
        )
      end

      before { order.user_id = 3 }

      it "sets confirmation value when its available via :cvc_confirm" do
        Spree::CreditCard.stub find: credit_card
        expect(credit_card).to receive(:verification_value=)
        order.update_from_params(params, permitted_params)
      end

      it "sets existing card as source for new payment" do
        expect {
          order.update_from_params(params, permitted_params)
        }.to change { Spree::Payment.count }.by(1)

        expect(Spree::Payment.last.source).to eq credit_card
      end

      it "sets request_env on payment" do
        request_env = { "USER_AGENT" => "Firefox" }

        expected_hash = { "payments_attributes" => [hash_including("request_env" => request_env)] }
        expect(order).to receive(:update_attributes).with expected_hash

        order.update_from_params(params, permitted_params, request_env)
      end

      it "dont let users mess with others users cards" do
        credit_card.update_column :user_id, 5

        expect {
          order.update_from_params(params, permitted_params)
        }.to raise_error
      end
    end

    context 'has params' do
      let(:permitted_params) { [ :good_param ] }
      let(:params) { ActionController::Parameters.new(order: {  bad_param: 'okay' } ) }

      it 'does not let through unpermitted attributes' do
        order.should_receive(:update_attributes).with({})
        order.update_from_params(params, permitted_params)
      end

      context 'has allowed params' do
        let(:params) { ActionController::Parameters.new(order: {  good_param: 'okay' } ) }

        it 'accepts permitted attributes' do
          order.should_receive(:update_attributes).with({"good_param" => 'okay'})
          order.update_from_params(params, permitted_params)
        end
      end

      context 'callbacks halt' do
        before do
          order.should_receive(:update_params_payment_source).and_return false
        end
        it 'does not let through unpermitted attributes' do
          order.should_not_receive(:update_attributes).with({})
          order.update_from_params(params, permitted_params)
        end
      end
    end
  end
end
