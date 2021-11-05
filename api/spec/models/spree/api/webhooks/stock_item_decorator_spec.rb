require 'spec_helper'

describe Spree::Api::Webhooks::StockItemDecorator do
  describe 'emitting variant.backorderable' do
    let(:body) { Spree::Api::V2::Platform::VariantSerializer.new(variant).serializable_hash.to_json }
    let(:variant) { create(:variant) }

    before do
      # makes sure variant.backorderable == false
      stock_item.update(backorderable: false)
    end

    let(:stock_item) { variant.stock_items.first }

    context 'when creating a variant stock item' do
      context 'when variant has no stock items' do
        before { variant.stock_items.delete_all }

        context 'when variant changes to be in stock' do
          context 'when variant changes to be backorderable' do
            it do
              expect do
                Timecop.freeze do
                  create(:stock_item, variant: variant, backorderable: true, count_on_hand: 1)
                end
              end.to emit_webhook_event('variant.backorderable')
            end
          end

          context 'when variant does not change to be backorderable' do
            it do
              expect do
                Timecop.freeze do
                  create(:stock_item, variant: variant, backorderable: false, count_on_hand: 1)
                end
              end.not_to emit_webhook_event('variant.backorderable')
            end
          end
        end

        context 'when variant does not change to be in stock' do
          it do
            expect do
              Timecop.freeze do
                create(:stock_item, variant: variant, backorderable: true, count_on_hand: 0)
              end
            end.not_to emit_webhook_event('variant.backorderable')
          end
        end
      end

      context 'when variant has stock items' do
        context 'when variant was out of stock' do
          context 'when variant changes to be in stock' do
            context 'when variant changes to be backorderable' do
              it do
                expect do
                  Timecop.freeze do
                    create(:stock_item, variant: variant, backorderable: true, count_on_hand: 1)
                  end
                end.to emit_webhook_event('variant.backorderable')
              end
            end

            context 'when variant does not change to be backorderable' do
              it do
                expect do
                  Timecop.freeze do
                    create(:stock_item, variant: variant, backorderable: false, count_on_hand: 1)
                  end
                end.not_to emit_webhook_event('variant.backorderable')
              end
            end
          end

          context 'when variant does not change to be in stock' do
            it do
              expect do
                Timecop.freeze do
                  create(:stock_item, variant: variant, backorderable: true, count_on_hand: 0)
                end
              end.not_to emit_webhook_event('variant.backorderable')
            end
          end
        end

        context 'when variant was not out of stock' do
          before { variant.stock_items.update_all(count_on_hand: 1, backorderable: true) }

          it do
            expect do
              Timecop.freeze do
                create(:stock_item, variant: variant, backorderable: true, count_on_hand: 1)
              end
            end.not_to emit_webhook_event('variant.backorderable')
          end
        end
      end
    end

    context 'when updating a variant stock item' do
      context 'when variant was out of stock' do
        context 'when variant changes to be in stock' do
          context 'when variant changes to backorderable' do
            before { variant.stock_items.update_all(backorderable: false) }

            it do
              expect do
                Timecop.freeze do
                  stock_item.update(backorderable: true, count_on_hand: 1)
                end
              end.to emit_webhook_event('variant.backorderable')
            end
          end

          context 'when variant does not change to backorderable' do
            before { variant.stock_items.update_all(backorderable: false) }

            it do
              expect do
                Timecop.freeze do
                  stock_item.update(backorderable: false, count_on_hand: 1)
                end
              end.not_to emit_webhook_event('variant.backorderable')
            end
          end

          context 'when variant was already backorderable' do
            before { stock_item.update(backorderable: true) }

            it do
              expect do
                Timecop.freeze do
                  stock_item.update(backorderable: true, count_on_hand: 1)
                end
              end.not_to emit_webhook_event('variant.backorderable')
            end
          end
        end

        context 'when variant does not change to be in stock' do
          before { variant.stock_items.update_all(backorderable: false) }

          it do
            expect do
              Timecop.freeze do
                stock_item.update(backorderable: true, count_on_hand: 0)
              end
            end.not_to emit_webhook_event('variant.backorderable')
          end
        end
      end

      context 'when variant was not out of stock' do
        before { stock_item.set_count_on_hand(1) }

        it do
          expect do
            Timecop.freeze do
              stock_item.update(backorderable: true)
            end
          end.not_to emit_webhook_event('variant.backorderable')
        end
      end
    end
  end
end
