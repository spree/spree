require 'spec_helper'

describe Spree::Order, type: :model do
  let(:order) { stub_model('Spree::Order') }

  before { create(:store) }

  context '#finalize!' do
    let(:order) { Spree::Order.create(email: 'test@example.com') }

    before do
      order.update_column :state, 'complete'
    end

    it 'sets completed_at' do
      expect(order).to receive(:touch).with(:completed_at)
      order.finalize!
    end

    it 'sells inventory units' do
      order.shipments.each do |shipment| # rubocop:disable RSpec/IteratedExpectation
        expect(shipment).to receive(:update!)
        expect(shipment).to receive(:finalize!)
      end
      order.finalize!
    end

    it 'decreases the stock for each variant in the shipment' do
      order.shipments.each do |shipment|
        expect(shipment.stock_location).to receive(:decrease_stock_for_variant)
      end
      order.finalize!
    end

    it 'changes the shipment state to ready if order is paid' do
      Spree::Shipment.create(order: order, stock_location: create(:stock_location))
      order.shipments.reload

      allow(order).to receive_messages(paid?: true, complete?: true)
      order.finalize!
      order.reload # reload so we're sure the changes are persisted
      expect(order.shipment_state).to eq('ready')
    end

    after { Spree::Config.set track_inventory_levels: true }
    it 'does not sell inventory units if track_inventory_levels is false' do
      Spree::Config.set track_inventory_levels: false
      expect(Spree::InventoryUnit).not_to receive(:sell_units)
      order.finalize!
    end

    it 'sends an order confirmation email' do
      mail_message = double 'Mail::Message'
      expect(Spree::OrderMailer).to receive(:confirm_email).with(order.id).and_return mail_message
      expect(mail_message).to receive :deliver_later
      order.finalize!
    end

    it 'sets confirmation delivered when finalizing' do
      expect(order.confirmation_delivered?).to be false
      order.finalize!
      expect(order.confirmation_delivered?).to be true
    end

    it 'does not send duplicate confirmation emails' do
      allow(order).to receive_messages(confirmation_delivered?: true)
      expect(Spree::OrderMailer).not_to receive(:confirm_email)
      order.finalize!
    end

    it 'freezes all adjustments' do
      allow(Spree::OrderMailer).to receive_message_chain :confirm_email, :deliver_later
      adjustments = [double]
      expect(order).to receive(:all_adjustments).and_return(adjustments)
      expect(adjustments).to all(receive(:close))
      order.finalize!
    end

    context 'order is considered risky' do
      before do
        allow(order).to receive_messages is_risky?: true
      end

      it 'changes state to risky' do
        expect(order).to receive(:considered_risky!)
        order.finalize!
      end

      context 'and order is approved' do
        before do
          allow(order).to receive_messages approved?: true
        end

        it 'leaves order in complete state' do
          order.finalize!
          expect(order.state).to eq 'complete'
        end
      end
    end

    context 'order is not considered risky' do
      before do
        allow(order).to receive_messages is_risky?: false
      end

      it 'sets completed_at' do
        order.finalize!
        expect(order.completed_at).to be_present
      end
    end
  end
end
