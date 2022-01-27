require 'spec_helper'

describe Spree::Api::Webhooks::StockMovementDecorator do
  let(:webhook_payload_body) do
    Spree::Api::V2::Platform::VariantSerializer.new(
      variant.reload,
      include: Spree::Api::V2::Platform::VariantSerializer.relationships_to_serialize.keys
    ).serializable_hash
  end
  let(:stock_item) { create(:stock_item) }
  let(:stock_location) { variant.stock_locations.first }

  describe 'emitting product events' do
    let!(:store) { create(:store) }
    let!(:product) { create(:product, stores: [store]) }
    let!(:variant) { create(:variant, product: product) }
    let!(:variant2) { create(:variant, product: product) }
    let(:webhook_payload_body) do
      Spree::Api::V2::Platform::ProductSerializer.new(
        product,
        include: Spree::Api::V2::Platform::ProductSerializer.relationships_to_serialize.keys
      ).serializable_hash
    end

    describe 'emitting product.out_of_stock' do
      let(:event_name) { 'product.out_of_stock' }
      let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }

      before { Spree::StockItem.update_all(backorderable: false) }

      context 'when all product variants are in stock' do
        before do
          product.variants.each do |variant|
            variant.stock_items.each do |stock_item|
              stock_item.set_count_on_hand(1)
            end
          end
        end

        context 'when one of the variants goes out of stock' do
          subject do
            stock_location.stock_movements.new.tap do |stock_movement|
              stock_movement.quantity = -1
              stock_movement.stock_item = stock_location.set_up_stock_item(variant)
              stock_movement.save
            end
            product.reload
          end

          it { expect { subject }.not_to emit_webhook_event(event_name) }
        end

        context 'when all the variants go out of stock' do
          subject do
            stock_location.stock_movements.new.tap do |stock_movement|
              stock_movement.quantity = -1
              stock_movement.stock_item = stock_location.set_up_stock_item(product.variants[1])
              stock_movement.save
            end
            product.reload
          end

          before do
            # Set one of the two product variants as out of stock
            stock_location.stock_movements.new.tap do |stock_movement|
              stock_movement.quantity = -1
              stock_movement.stock_item = stock_location.set_up_stock_item(product.variants[0])
              stock_movement.save
            end
          end

          it { expect { subject }.to emit_webhook_event(event_name) }
        end
      end

      context 'when only one product variant is in stock' do
        subject do
          stock_location.stock_movements.new.tap do |stock_movement|
            stock_movement.quantity = -1
            stock_movement.stock_item = stock_location.set_up_stock_item(product.variants[0])
            stock_movement.save
          end
          product.reload
        end

        before { product.variants[0].stock_items[0].set_count_on_hand(1) }

        it { expect { subject }.to emit_webhook_event(event_name) }
      end

      context 'when no product variant is in stock' do
        subject do
          stock_location.stock_movements.new.tap do |stock_movement|
            stock_movement.quantity = 0
            stock_movement.stock_item = stock_location.set_up_stock_item(product.variants[0])
            stock_movement.save
          end
          product.reload
        end

        before do
          product.variants.each do |variant|
            variant.stock_items.each do |stock_item|
              stock_item.set_count_on_hand(0)
            end
          end
        end

        it { expect { subject }.not_to emit_webhook_event(event_name) }
      end
    end

    describe 'emitting product.back_in_stock' do
      let(:event_name) { 'product.back_in_stock' }
      let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }

      before { Spree::StockItem.update_all(backorderable: false) }

      context 'when all product variants are out of stock' do
        context 'when one of the variants is back in stock' do
          subject do
            stock_location.stock_movements.new.tap do |stock_movement|
              stock_movement.quantity = 1
              stock_movement.stock_item = stock_location.set_up_stock_item(variant)
              stock_movement.save
            end
            product.reload
          end

          it { expect { subject }.to emit_webhook_event(event_name) }
        end

        context 'when none of the variants is back in stock' do
          subject do
            stock_location.stock_movements.new.tap do |stock_movement|
              stock_movement.quantity = 0
              stock_movement.stock_item = stock_location.set_up_stock_item(variant)
              stock_movement.save
            end
            product.reload
          end

          it { expect { subject }.not_to emit_webhook_event(event_name) }
        end
      end

      context 'when other variant is already in stock' do
        subject do
          stock_location.stock_movements.new.tap do |stock_movement|
            stock_movement.quantity = 100
            stock_movement.stock_item = stock_location.set_up_stock_item(variant)
            stock_movement.save
          end
        end

        before do
          stock_location.stock_movements.new.tap do |stock_movement|
            stock_movement.quantity = 1
            stock_movement.stock_item = stock_location.set_up_stock_item(variant2)
            stock_movement.save
          end
        end

        it { expect { subject }.not_to emit_webhook_event(event_name) }
      end
    end
  end

  describe 'emitting variant.back_in_stock' do
    let(:variant) { create(:variant, track_inventory: true) }
    let(:event_name) { 'variant.back_in_stock' }
    let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }

    context 'when stock item was out of stock' do
      context 'when stock item changes to be in stock' do
        it do
          expect do
            variant.stock_items.update_all(backorderable: false)
            stock_location.stock_movements.new.tap do |stock_movement|
              stock_movement.quantity = 1 # does make it to be in stock
              stock_movement.stock_item = stock_location.set_up_stock_item(variant)
              stock_movement.save
            end
          end.to emit_webhook_event(event_name)
        end
      end

      context 'when stock item does not change to be in stock' do
        it do
          expect do
            variant.stock_items.update_all(backorderable: false)
            stock_location.stock_movements.new.tap do |stock_movement|
              stock_movement.quantity = 0 # does not make it to be in stock
              stock_movement.stock_item = stock_location.set_up_stock_item(variant)
              stock_movement.save
            end
          end.not_to emit_webhook_event(event_name)
        end
      end
    end

    context 'when stock item was in stock' do
      it do
        expect do
          # make in_stock? return false based on track_inventory, the easiest case
          variant.update(track_inventory: false)
          stock_location.stock_movements.new.tap do |stock_movement|
            stock_movement.quantity = 2
            stock_movement.stock_item = stock_location.set_up_stock_item(variant)
            stock_movement.save
          end
        end.not_to emit_webhook_event(event_name)
      end
    end
  end

  describe 'emitting variant.out_of_stock' do
    subject { stock_movement }

    let(:stock_movement) { create(:stock_movement, stock_item: stock_item, quantity: movement_quantity) }
    let(:event_name) { 'variant.out_of_stock' }
    let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }
    let!(:variant) { stock_item.variant }

    before do
      Spree::StockItem.update_all(backorderable: false)
    end

    describe 'when the variant goes out of stock' do
      let(:movement_quantity) { -stock_item.count_on_hand }

      it 'emits the variant.out_of_stock event' do
        ActiveRecord::Base.no_touching do
          expect { subject }.to emit_webhook_event(event_name)
        end
      end
    end

    describe 'when the variant does not go out of stock' do
      let(:movement_quantity) { -stock_item.count_on_hand + 1 }

      it 'does not emit the variant.out_of_stock event' do
        expect { subject }.not_to emit_webhook_event(event_name)
      end
    end

    describe 'when the variant was out of stock before the update and after the update' do
      before { stock_item.set_count_on_hand(0) }

      let(:movement_quantity) { 0 }

      it 'does not emit the variant.out_of_stock event' do
        expect { subject }.not_to emit_webhook_event(event_name)
      end
    end
  end
end
