require 'spec_helper'

describe Spree::Api::Webhooks::StockItemDecorator do
  let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant.reload, mock_serializer_params(event: params)).serializable_hash.to_json }
  let(:variant) { create(:variant) }
  let(:stock_item) { variant.stock_items.first }
  let(:stock_location) { variant.stock_locations.first }

  describe 'emitting product.backorderable' do
    subject do
      product.reload
      Timecop.freeze { stock_item.update(backorderable: backorderable) }
    end

    let(:body) { Spree::Api::V2::Platform::ProductSerializer.new(product.reload, mock_serializer_params(event: params)).serializable_hash.to_json }
    let(:product) { variant.product }
    let(:params) { 'product.backorderable' }
    let!(:variant2) { create(:variant, product: product) }

    before { Spree::StockItem.update_all(backorderable: false) }

    context 'when product was out of stock' do
      context 'when none of the product variants is backorderable' do
        context 'when one of the variants is made backorderable' do
          let(:backorderable) { true }

          it { expect { subject }.to emit_webhook_event(params) }
        end

        context 'when none of the variants is made backorderable' do
          let(:backorderable) { false }

          it { expect { subject }.not_to emit_webhook_event(params) }
        end
      end

      context 'when other variant is already backorderable' do
        let(:another_stock_item) { variant2.stock_items.first }

        context 'when other variant is made backorderable' do
          let(:backorderable) { true }

          before do
            another_stock_item.update(backorderable: true)
          end

          it { expect { subject }.not_to emit_webhook_event(params) }
        end
      end
    end

    context 'when product was in stock' do
      let(:backorderable) { true }

      before do
        stock_location.stock_movements.new.tap do |stock_movement|
          stock_movement.quantity = 1
          stock_movement.stock_item = stock_location.set_up_stock_item(variant)
          stock_movement.save
        end
      end

      it { expect { subject }.not_to emit_webhook_event(params) }
    end
  end

  describe 'emitting variant.backorderable' do
    subject { stock_item.save }

    let(:params) { 'variant.backorderable' }

    context 'when variant was out of stock' do
      before do
        stock_location.stock_movements.new.tap do |stock_movement|
          stock_movement.quantity = 0
          stock_movement.stock_item = stock_location.set_up_stock_item(variant)
          stock_movement.save
        end
      end

      context 'when variant was backorderable' do
        before { stock_item.backorderable = true }

        it { expect { subject }.not_to emit_webhook_event(params) }
      end

      context 'when variant was not backorderable' do
        before { variant.stock_items.update_all(backorderable: false) }

        context 'when variant is not set as backorderable' do
          before { stock_item.backorderable = false }

          it { expect { subject }.not_to emit_webhook_event(params) }
        end

        context 'when variant is set as backorderable' do
          before { stock_item.backorderable = true }

          it { expect { subject }.to emit_webhook_event(params) }
        end
      end
    end

    context 'when variant was not out of stock' do
      before do
        variant.stock_items.update_all(backorderable: false)
        stock_location.stock_movements.new.tap do |stock_movement|
          stock_movement.quantity = 1
          stock_movement.stock_item = stock_location.set_up_stock_item(variant)
          stock_movement.save
        end
        stock_item.backorderable = true
      end

      it { expect { subject }.not_to emit_webhook_event(params) }
    end
  end
end
