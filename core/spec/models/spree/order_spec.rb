# encoding: utf-8

require 'spec_helper'

class FakeCalculator < Spree::Calculator
  def compute(computable)
    5
  end
end

describe Spree::Order, :type => :model do
  let(:user) { stub_model(Spree::LegacyUser, :email => "spree@example.com") }
  let(:order) { stub_model(Spree::Order, :user => user) }

  before do
    allow(Spree::LegacyUser).to receive_messages(:current => mock_model(Spree::LegacyUser, :id => 123))
  end

  context "#create" do
    let(:order) { Spree::Order.create }

    it "should assign an order number" do
      expect(order.number).not_to be_nil
    end

    it 'should create a randomized 22 character token' do
      expect(order.guest_token.size).to eq(22)
    end
  end

  context "#create_adjustment!" do
    let(:order) { create(:order) }

    it 'calls #update_adjustable_adjustment_total on adjustment' do
      scope      = double('scope')
      attributes = double('attributes')
      adjustment = double('adjustment')
      expect(order).to receive(:all_adjustments).and_return(scope)
      expect(scope).to receive(:create!).with(attributes).and_return(adjustment)
      expect(adjustment).to receive(:update_adjustable_adjustment_total)
      order.create_adjustment!(attributes)
    end
  end

  context "creates shipments cost" do
    let(:shipment) { double }

    before { allow(order).to receive_messages shipments: [shipment] }

    it "update and persist totals" do
      expect(shipment).to receive :update_amounts
      expect(order.updater).to receive :update_shipment_total
      expect(order.updater).to receive :persist_totals

      order.set_shipments_cost
    end
  end

  context "#finalize!" do
    let(:order) { Spree::Order.create(email: 'test@example.com') }

    before do
      order.update_column :state, 'complete'
    end

    it "should set completed_at" do
      expect(order).to receive(:touch).with(:completed_at)
      order.finalize!
    end

    it "should sell inventory units" do
      order.shipments.each do |shipment|
        expect(shipment).to receive(:update!)
        expect(shipment).to receive(:finalize!)
      end
      order.finalize!
    end

    it "should decrease the stock for each variant in the shipment" do
      order.shipments.each do |shipment|
        expect(shipment.stock_location).to receive(:decrease_stock_for_variant)
      end
      order.finalize!
    end

    it "should change the shipment state to ready if order is paid" do
      Spree::Shipment.create(order: order)
      order.shipments.reload

      allow(order).to receive_messages(:paid? => true, :complete? => true)
      order.finalize!
      order.reload # reload so we're sure the changes are persisted
      expect(order.shipment_state).to eq('ready')
    end

    after { Spree::Config.set :track_inventory_levels => true }
    it "should not sell inventory units if track_inventory_levels is false" do
      Spree::Config.set :track_inventory_levels => false
      expect(Spree::InventoryUnit).not_to receive(:sell_units)
      order.finalize!
    end

    it "should send an order confirmation email" do
      mail_message = double "Mail::Message"
      expect(Spree::OrderMailer).to receive(:confirm_email).with(order.id).and_return mail_message
      expect(mail_message).to receive :deliver
      order.finalize!
    end

    it "sets confirmation delivered when finalizing" do
      expect(order.confirmation_delivered?).to be false
      order.finalize!
      expect(order.confirmation_delivered?).to be true
    end

    it "should not send duplicate confirmation emails" do
      allow(order).to receive_messages(:confirmation_delivered? => true)
      expect(Spree::OrderMailer).not_to receive(:confirm_email)
      order.finalize!
    end

    it "should freeze all adjustments" do
      # Stub this method as it's called due to a callback
      # and it's irrelevant to this test
      allow(order).to receive :has_available_shipment
      allow(Spree::OrderMailer).to receive_message_chain :confirm_email, :deliver
      adjustments = [double]
      expect(order).to receive(:all_adjustments).and_return(adjustments)
      adjustments.each do |adj|
        expect(adj).to receive(:close)
      end
      order.finalize!
    end

    context "order is considered risky" do
      before do
        allow(order).to receive_messages :is_risky? => true
      end

      it "should change state to risky" do
        expect(order).to receive(:considered_risky!)
        order.finalize!
      end

      context "and order is approved" do
        before do
          allow(order).to receive_messages :approved? => true
        end

        it "should leave order in complete state" do
          order.finalize!
          expect(order.state).to eq 'complete'
        end
      end
    end
  end

  context "insufficient_stock_lines" do
    let(:line_item) { mock_model Spree::LineItem, :insufficient_stock? => true }

    before { allow(order).to receive_messages(:line_items => [line_item]) }

    it "should return line_item that has insufficient stock on hand" do
      expect(order.insufficient_stock_lines.size).to eq(1)
      expect(order.insufficient_stock_lines.include?(line_item)).to be true
    end
  end

  describe '#ensure_line_items_are_in_stock' do
    subject { order.ensure_line_items_are_in_stock }

    let(:line_item) { mock_model Spree::LineItem, :insufficient_stock? => true }

    before do
      allow(order).to receive(:restart_checkout_flow)
      allow(order).to receive_messages(:line_items => [line_item])
    end

    it 'should restart checkout flow' do
      expect(order).to receive(:restart_checkout_flow).once
      subject
    end

    it 'should have error message' do
      subject
      expect(order.errors[:base]).to include(Spree.t(:insufficient_stock_lines_present))
    end

    it 'should be false' do
      expect(subject).to be_falsey
    end
  end

  context "empty!" do
    let(:order) { stub_model(Spree::Order, item_count: 2) }

    before do
      allow(order).to receive_messages(line_items: line_items = [1, 2])
      allow(order).to receive_messages(adjustments: [])
      allow(order).to receive_message_chain(:line_items, sum: 0)
    end

    it "clears out line items, adjustments and update totals" do
      expect(order.line_items).to receive(:destroy_all)
      expect(order.adjustments).to receive(:destroy_all)
      expect(order.shipments).to receive(:destroy_all)
      expect(order.updater).to receive(:update_totals)
      expect(order.updater).to receive(:persist_totals)

      order.empty!
      expect(order.item_total).to eq 0
    end
  end

  context "#display_outstanding_balance" do
    it "returns the value as a spree money" do
      allow(order).to receive(:outstanding_balance) { 10.55 }
      expect(order.display_outstanding_balance).to eq(Spree::Money.new(10.55))
    end
  end

  context "#display_item_total" do
    it "returns the value as a spree money" do
      allow(order).to receive(:item_total) { 10.55 }
      expect(order.display_item_total).to eq(Spree::Money.new(10.55))
    end
  end

  context "#display_adjustment_total" do
    it "returns the value as a spree money" do
      order.adjustment_total = 10.55
      expect(order.display_adjustment_total).to eq(Spree::Money.new(10.55))
    end
  end

  context "#display_total" do
    it "returns the value as a spree money" do
      order.total = 10.55
      expect(order.display_total).to eq(Spree::Money.new(10.55))
    end
  end

  context "#currency" do
    context "when object currency is ABC" do
      before { order.currency = "ABC" }

      it "returns the currency from the object" do
        expect(order.currency).to eq("ABC")
      end
    end

    context "when object currency is nil" do
      before { order.currency = nil }

      it "returns the globally configured currency" do
        expect(order.currency).to eq("USD")
      end
    end
  end

  # Regression tests for #2179
  context "#merge!" do
    let(:variant) { create(:variant) }
    let(:order_1) { Spree::Order.create }
    let(:order_2) { Spree::Order.create }

    shared_examples '#merge!' do
      it "destroys the other order" do
        order_1.merge!(order_2)
        expect { order_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "returns self" do
        expect(order_1.merge!(order_2)).to be(order_1)
      end
    end

    context "merging together two orders with line items for the same variant" do
      include_examples '#merge!'

      before do
        order_1.contents.add(variant, 1)
        order_2.contents.add(variant, 1)
      end

      specify do
        order_1.merge!(order_2)
        expect(order_1.line_items.count).to eq(1)

        line_item = order_1.line_items.first
        expect(line_item.quantity).to eq(2)
        expect(line_item.variant_id).to eq(variant.id)
      end
    end

    context "merging together two orders with different line items" do
      include_examples '#merge!'

      let(:variant_2) { create(:variant) }

      before do
        order_1.contents.add(variant, 1)
        order_2.contents.add(variant_2, 1)
      end

      specify do
        order_1.merge!(order_2)
        line_items = order_1.line_items
        expect(line_items.count).to eq(2)

        expect(order_1.item_count).to eq 2
        expect(order_1.item_total).to eq line_items.map(&:amount).sum

        # No guarantee on ordering of line items, so we do this:
        expect(line_items.pluck(:quantity)).to match_array([1, 1])
        expect(line_items.pluck(:variant_id)).to match_array([variant.id, variant_2.id])
      end
    end
  end

  context "#confirmation_required?" do

    # Regression test for #4117
    it "is required if the state is currently 'confirm'" do
      order = Spree::Order.new
      assert !order.confirmation_required?
      order.state = 'confirm'
      assert order.confirmation_required?
    end

    context 'Spree::Config[:always_include_confirm_step] == true' do

      before do
        Spree::Config[:always_include_confirm_step] = true
      end

      it "returns true if payments empty" do
        order = Spree::Order.new
        assert order.confirmation_required?
      end
    end

    context 'Spree::Config[:always_include_confirm_step] == false' do

      it "returns false if payments empty and Spree::Config[:always_include_confirm_step] == false" do
        order = Spree::Order.new
        assert !order.confirmation_required?
      end

      it "does not bomb out when an order has an unpersisted payment" do
        order = Spree::Order.new
        order.payments.build
        assert !order.confirmation_required?
      end
    end
  end


  context "add_update_hook" do
    before do
      Spree::Order.class_eval do
        register_update_hook :add_awesome_sauce
      end
    end

    after do
      Spree::Order.update_hooks = Set.new
    end

    it "calls hook during update" do
      order = create(:order)
      expect(order).to receive(:add_awesome_sauce)
      order.update!
    end

    it "calls hook during finalize" do
      order = create(:order)
      expect(order).to receive(:add_awesome_sauce)
      order.finalize!
    end
  end

  describe "#tax_address" do
    before { Spree::Config[:tax_using_ship_address] = tax_using_ship_address }
    subject { order.tax_address }

    context "when tax_using_ship_address is true" do
      let(:tax_using_ship_address) { true }

      it 'returns ship_address' do
        expect(subject).to eq(order.ship_address)
      end
    end

    context "when tax_using_ship_address is not true" do
      let(:tax_using_ship_address) { false }

      it "returns bill_address" do
        expect(subject).to eq(order.bill_address)
      end
    end
  end

  describe "#restart_checkout_flow" do
    it "updates the state column to the first checkout_steps value" do
      order = create(:order, :state => "delivery")
      expect(order.checkout_steps).to eql ["address", "delivery", "complete"]
      expect{ order.restart_checkout_flow }.to change{order.state}.from("delivery").to("address")
    end

    context "with custom checkout_steps" do
      it "updates the state column to the first checkout_steps value" do
        order = create(:order, :state => "delivery")
        expect(order).to receive(:checkout_steps).and_return ["custom_step", "address", "delivery", "complete"]
        expect{ order.restart_checkout_flow }.to change{order.state}.from("delivery").to("custom_step")
      end
    end
  end

  # Regression tests for #4072
  context "#state_changed" do
    let(:order) { FactoryGirl.create(:order) }

    it "logs state changes" do
      order.update_column(:payment_state, 'balance_due')
      order.payment_state = 'paid'
      expect(order.state_changes).to be_empty
      order.state_changed('payment')
      state_change = order.state_changes.find_by(:name => 'payment')
      expect(state_change.previous_state).to eq('balance_due')
      expect(state_change.next_state).to eq('paid')
    end

    it "does not do anything if state does not change" do
      order.update_column(:payment_state, 'balance_due')
      expect(order.state_changes).to be_empty
      order.state_changed('payment')
      expect(order.state_changes).to be_empty
    end
  end

  # Regression test for #4199
  context "#available_payment_methods" do
    it "includes frontend payment methods" do
      payment_method = Spree::PaymentMethod.create!({
        :name => "Fake",
        :active => true,
        :display_on => "front_end",
        :environment => Rails.env
      })
      expect(order.available_payment_methods).to include(payment_method)
    end

    it "includes 'both' payment methods" do
      payment_method = Spree::PaymentMethod.create!({
        :name => "Fake",
        :active => true,
        :display_on => "both",
        :environment => Rails.env
      })
      expect(order.available_payment_methods).to include(payment_method)
    end

    it "does not include a payment method twice if display_on is blank" do
      payment_method = Spree::PaymentMethod.create!({
        :name => "Fake",
        :active => true,
        :display_on => "both",
        :environment => Rails.env
      })
      expect(order.available_payment_methods.count).to eq(1)
      expect(order.available_payment_methods).to include(payment_method)
    end
  end

  context "#apply_free_shipping_promotions" do
    it "calls out to the FreeShipping promotion handler" do
      shipment = double('Shipment')
      allow(order).to receive_messages :shipments => [shipment]
      expect(Spree::PromotionHandler::FreeShipping).to receive(:new).and_return(handler = double)
      expect(handler).to receive(:activate)

      expect(Spree::ItemAdjustments).to receive(:new).with(shipment).and_return(adjuster = double)
      expect(adjuster).to receive(:update)

      expect(order.updater).to receive(:update_shipment_total)
      expect(order.updater).to receive(:persist_totals)
      order.apply_free_shipping_promotions
    end
  end


  context "#products" do
    before :each do
      @variant1 = mock_model(Spree::Variant, :product => "product1")
      @variant2 = mock_model(Spree::Variant, :product => "product2")
      @line_items = [mock_model(Spree::LineItem, :product => "product1", :variant => @variant1, :variant_id => @variant1.id, :quantity => 1),
                     mock_model(Spree::LineItem, :product => "product2", :variant => @variant2, :variant_id => @variant2.id, :quantity => 2)]
      allow(order).to receive_messages(:line_items => @line_items)
    end

    it "contains?" do
      expect(order.contains?(@variant1)).to be true
    end

    it "gets the quantity of a given variant" do
      expect(order.quantity_of(@variant1)).to eq(1)

      @variant3 = mock_model(Spree::Variant, :product => "product3")
      expect(order.quantity_of(@variant3)).to eq(0)
    end

    it "can find a line item matching a given variant" do
      expect(order.find_line_item_by_variant(@variant1)).not_to be_nil
      expect(order.find_line_item_by_variant(mock_model(Spree::Variant))).to be_nil
    end
  end

  describe "#associate_user!" do
    let(:user) { FactoryGirl.create(:user_with_addreses) }
    let(:email) { user.email }
    let(:created_by) { user }
    let(:bill_address) { user.bill_address }
    let(:ship_address) { user.ship_address }
    let(:override_email) { true }

    let(:order) { FactoryGirl.build(:order, order_attributes) }

    let(:order_attributes) do
      {
        user:         nil,
        email:        nil,
        created_by:   nil,
        bill_address: nil,
        ship_address: nil
      }
    end

    def assert_expected_order_state
      expect(order.user).to eql(user)
      expect(order.user_id).to eql(user.id)

      expect(order.email).to eql(email)

      expect(order.created_by).to eql(created_by)
      expect(order.created_by_id).to eql(created_by.id)

      expect(order.bill_address).to eql(bill_address)
      expect(order.bill_address_id).to eql(bill_address.id)

      expect(order.ship_address).to eql(ship_address)
      expect(order.ship_address_id).to eql(ship_address.id)
    end

    shared_examples_for "#associate_user!" do |persisted = false|
      it "associates a user to an order" do
        order.associate_user!(user, override_email)
        assert_expected_order_state
      end

      unless persisted
        it "does not persist the order" do
          expect { order.associate_user!(user) }
            .to_not change(order, :persisted?)
            .from(false)
        end
      end

      it "returns self" do
        expect(order.associate_user!(user, override_email)).to be(order)
      end
    end

    context "when user is nil" do
      let(:user) { nil }

      it "raises an error" do
        expect { order.associate_user!(user) }
          .to raise_error(NoMethodError)
      end
    end

    context "when email is set" do
      let(:order_attributes) { super().merge(email: 'test@example.com') }

      context "when email should be overridden" do
        it_should_behave_like "#associate_user!"
      end

      context "when email should not be overridden" do
        let(:override_email) { false }
        let(:email) { 'test@example.com' }

        it_should_behave_like "#associate_user!"
      end
    end

    context "when created_by is set" do
      let(:order_attributes) { super().merge(created_by: created_by) }
      let(:created_by) { create(:user_with_addreses) }

      it_should_behave_like "#associate_user!"
    end

    context "when bill_address is set" do
      let(:order_attributes) { super().merge(bill_address: bill_address) }
      let(:bill_address) { FactoryGirl.build(:address) }

      it_should_behave_like "#associate_user!"
    end

    context "when ship_address is set" do
      let(:order_attributes) { super().merge(ship_address: ship_address) }
      let(:ship_address) { FactoryGirl.build(:address) }

      it_should_behave_like "#associate_user!"
    end

    context "when the user is not persisted" do
      let(:user) { FactoryGirl.build(:user_with_addreses) }

      it "does not persist the user" do
        expect { order.associate_user!(user) }
          .to_not change(user, :persisted?)
          .from(false)
      end

      it_should_behave_like "#associate_user!"
    end

    context "when the order is persisted" do
      let(:order) { FactoryGirl.create(:order, order_attributes) }

      it "associates a user to a persisted order" do
        order.associate_user!(user)
        order.reload
        assert_expected_order_state
      end

      it "does not persist other changes to the order" do
        order.state = 'complete'
        order.associate_user!(user)
        order.reload
        expect(order.state).to eql('cart')
      end

      it "does not change any other orders" do
        other = FactoryGirl.create(:order)
        order.associate_user!(user)
        expect(other.reload.user).to_not eql(user)
      end

      it "is not affected by scoping" do
        order.class.where.not(id: order).scoping do
          order.associate_user!(user)
        end
        order.reload
        assert_expected_order_state
      end

      it_should_behave_like "#associate_user!", true
    end
  end

  context "#can_ship?" do
    let(:order) { Spree::Order.create }

    it "should be true for order in the 'complete' state" do
      allow(order).to receive_messages(:complete? => true)
      expect(order.can_ship?).to be true
    end

    it "should be true for order in the 'resumed' state" do
      allow(order).to receive_messages(:resumed? => true)
      expect(order.can_ship?).to be true
    end

    it "should be true for an order in the 'awaiting return' state" do
      allow(order).to receive_messages(:awaiting_return? => true)
      expect(order.can_ship?).to be true
    end

    it "should be true for an order in the 'returned' state" do
      allow(order).to receive_messages(:returned? => true)
      expect(order.can_ship?).to be true
    end

    it "should be false if the order is neither in the 'complete' nor 'resumed' state" do
      allow(order).to receive_messages(:resumed? => false, :complete? => false)
      expect(order.can_ship?).to be false
    end
  end

  context "#completed?" do
    it "should indicate if order is completed" do
      order.completed_at = nil
      expect(order.completed?).to be false

      order.completed_at = Time.now
      expect(order.completed?).to be true
    end
  end

  context "#allow_checkout?" do
    it "should be true if there are line_items in the order" do
      allow(order).to receive_message_chain(:line_items, :count => 1)
      expect(order.checkout_allowed?).to be true
    end
    it "should be false if there are no line_items in the order" do
      allow(order).to receive_message_chain(:line_items, :count => 0)
      expect(order.checkout_allowed?).to be false
    end
  end

  context "#amount" do
    before do
      @order = create(:order, :user => user)
      @order.line_items = [create(:line_item, :price => 1.0, :quantity => 2),
                           create(:line_item, :price => 1.0, :quantity => 1)]
    end
    it "should return the correct lum sum of items" do
      expect(@order.amount).to eq(3.0)
    end
  end

  context "#backordered?" do
    it 'is backordered if one of the shipments is backordered' do
      allow(order).to receive_messages(:shipments => [mock_model(Spree::Shipment, :backordered? => false),
                                mock_model(Spree::Shipment, :backordered? => true)])
      expect(order).to be_backordered
    end
  end

  context "#can_cancel?" do
    it "should be false for completed order in the canceled state" do
      order.state = 'canceled'
      order.shipment_state = 'ready'
      order.completed_at = Time.now
      expect(order.can_cancel?).to be false
    end

    it "should be true for completed order with no shipment" do
      order.state = 'complete'
      order.shipment_state = nil
      order.completed_at = Time.now
      expect(order.can_cancel?).to be true
    end
  end

  context "#tax_total" do
    it "adds included tax and additional tax" do
      allow(order).to receive_messages(:additional_tax_total => 10, :included_tax_total => 20)

      expect(order.tax_total).to eq 30
    end
  end

  context '#destroy' do
    it 'destroys adjustents' do
      order = create(:order)
      order.create_adjustment!(
        adjustable: order,
        label:      'Test Adjustment',
        amount:     100
      )
      expect { order.destroy }.to change { Spree::Adjustment.where(adjustable_id: order.id).count }.by(-1)
    end
  end

  # Regression test for #4923
  context "locking" do
    let(:order) { Spree::Order.create } # need a persisted in order to test locking

    it 'can lock' do
      expect { order.with_lock {} }.to_not raise_error
    end
  end

  describe '#quantity' do
    # Uses a persisted record, as the quantity is retrieved via a DB count
    let(:order) { create :order_with_line_items }

    it 'sums the quantity of all line items' do
      expect(order.quantity).to eq 5
    end
  end
end
