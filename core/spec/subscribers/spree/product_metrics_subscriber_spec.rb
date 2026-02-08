# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ProductMetricsSubscriber do
  include ActiveJob::TestHelper

  describe '.subscription_patterns' do
    it 'subscribes to order.completed event' do
      expect(described_class.subscription_patterns).to include('order.completed')
    end
  end

  describe '.event_handlers' do
    it 'routes order.completed to refresh_product_metrics' do
      expect(described_class.event_handlers['order.completed']).to eq(:refresh_product_metrics)
    end
  end

  describe '#refresh_product_metrics' do
    let(:store) { @default_store }
    let(:product_1) { create(:product, stores: [store]) }
    let(:product_2) { create(:product, stores: [store]) }
    let(:subscriber) { described_class.new }

    let(:order) do
      create(:completed_order_with_totals, store: store).tap do |o|
        o.line_items.first.update!(product: product_1, variant: product_1.master)
        create(:line_item, order: o, product: product_2, variant: product_2.master)
      end
    end

    let(:event) do
      Spree::Event.new(
        name: 'order.completed',
        payload: { 'id' => order.id, 'store_id' => store.id }
      )
    end

    it 'enqueues refresh jobs for all products in the order' do
      expect {
        subscriber.refresh_product_metrics(event)
      }.to have_enqueued_job(Spree::Products::RefreshMetricsJob).exactly(2).times
    end

    it 'enqueues jobs with correct arguments' do
      subscriber.refresh_product_metrics(event)

      expect(Spree::Products::RefreshMetricsJob).to have_been_enqueued.with(product_1.id, store.id)
      expect(Spree::Products::RefreshMetricsJob).to have_been_enqueued.with(product_2.id, store.id)
    end

    context 'when order_id is missing' do
      let(:event) do
        Spree::Event.new(
          name: 'order.completed',
          payload: { 'store_id' => store.id }
        )
      end

      it 'does not enqueue any jobs' do
        expect {
          subscriber.refresh_product_metrics(event)
        }.not_to have_enqueued_job(Spree::Products::RefreshMetricsJob)
      end
    end

    context 'when order has no store' do
      let(:order_without_store) do
        create(:completed_order_with_totals, store: store).tap do |o|
          o.update_column(:store_id, nil)
        end
      end

      let(:event) do
        Spree::Event.new(
          name: 'order.completed',
          payload: { 'id' => order_without_store.id }
        )
      end

      it 'does not enqueue any jobs' do
        expect {
          subscriber.refresh_product_metrics(event)
        }.not_to have_enqueued_job(Spree::Products::RefreshMetricsJob)
      end
    end

    context 'when order does not exist' do
      let(:event) do
        Spree::Event.new(
          name: 'order.completed',
          payload: { 'id' => 'non-existent-id', 'store_id' => store.id }
        )
      end

      it 'does not enqueue any jobs' do
        expect {
          subscriber.refresh_product_metrics(event)
        }.not_to have_enqueued_job(Spree::Products::RefreshMetricsJob)
      end
    end

    context 'when order has no line items' do
      let(:order_without_items) { create(:order, store: store, completed_at: Time.current) }

      let(:event) do
        Spree::Event.new(
          name: 'order.completed',
          payload: { 'id' => order_without_items.id, 'store_id' => store.id }
        )
      end

      it 'does not enqueue any jobs' do
        expect {
          subscriber.refresh_product_metrics(event)
        }.not_to have_enqueued_job(Spree::Products::RefreshMetricsJob)
      end
    end

    context 'when order has duplicate products' do
      let(:order_with_duplicates) do
        create(:completed_order_with_totals, store: store).tap do |o|
          o.line_items.first.update!(product: product_1, variant: product_1.master)
          create(:line_item, order: o, product: product_1, variant: product_1.master)
        end
      end

      let(:event) do
        Spree::Event.new(
          name: 'order.completed',
          payload: { 'id' => order_with_duplicates.id, 'store_id' => store.id }
        )
      end

      it 'only enqueues one job per unique product' do
        expect {
          subscriber.refresh_product_metrics(event)
        }.to have_enqueued_job(Spree::Products::RefreshMetricsJob).exactly(1).times
      end
    end
  end
end
