require 'spec_helper'

describe Spree::Webhooks::HasWebhooks do
  let(:images) { create_list(:image, 2) }
  let(:store) { create(:store) }
  let(:variant_with_images) { create(:variant, images: images) }
  let(:variant) { build(:variant) }
  let(:product) do
    build(
      :product_in_stock,
      variants_including_master: [variant_with_images, variant],
      stores: [store]
    )
  end
  let(:store) { create(:store) }

  context 'with DISABLE_SPREE_WEBHOOKS equals "true" (set in spec_helper)' do
    let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }

    before do
      allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
      product.save
    end

    shared_examples 'not queueing an event request' do |event_name|
      it { expect(queue_requests).not_to have_received(:call).with(hash_including(event: event_name)) }
    end

    context 'after_create_commit' do
      it_behaves_like 'not queueing an event request', 'product.create'
    end

    context 'after_destroy_commit' do
      before { product.destroy }

      it_behaves_like 'not queueing an event request', 'product.delete'
    end

    context 'after_update_commit' do
      before { product.update(name: 'updated') }

      it_behaves_like 'not queueing an event request', 'product.update'
    end
  end

  context 'without DISABLE_SPREE_WEBHOOKS' do
    let(:body) { Spree::Api::V2::Platform::ProductSerializer.new(product).serializable_hash }

    context 'after_create_commit' do
      it { expect { product.save }.to emit_webhook_event('product.create') }
    end

    context 'after_destroy_commit' do
      before { product.save }

      it { expect { product.destroy }.to emit_webhook_event('product.delete') }
    end

    context 'after_update_commit' do
      before { product.save }

      it { expect { product.update(name: 'updated') }.to emit_webhook_event('product.update') }
    end

    context 'with a class name with multiple words' do
      let(:body) { Spree::Api::V2::Platform::CmsPageSerializer.new(cms_page).serializable_hash }
      let(:cms_page) { create(:cms_homepage, store: store, locale: 'en') }
      let(:event_name) { 'cms_page.create' }

      it 'underscorizes the event name' do
        expect { cms_page }.to emit_webhook_event(event_name)
      end
    end

    context 'when only timestamps change' do
      let(:event_name) { 'product.update' }

      before { product.save }

      context 'on created_at change' do
        it do
          expect do
            product.update(created_at: Date.yesterday)
          end.not_to emit_webhook_event(event_name)
        end
      end

      context 'on updated_at change' do
        it do
          expect do
            product.update(updated_at: Date.yesterday)
          end.not_to emit_webhook_event(event_name)
        end
      end

      context 'when using touch without arguments' do
        it do
          expect do
            # Doing product.touch in Rails 5.2 doesn't work at the first time.
            # It must be done twice in order to update the updated_at column.
            Spree::Product.find(product.id).touch
          end.not_to emit_webhook_event(event_name)
        end
      end

      context 'when using touch with an argument other than created_at/updated_at' do
        it do
          expect do
            product.touch(:deleted_at)
          end.to emit_webhook_event(event_name)
        end
      end
    end
  end

  describe '.default_webhook_events' do
    it 'return the default events' do
      expect(Spree::Order.default_webhook_events).to eq(%w[order.create order.destroy order.update])
    end
  end

  describe '.supported_webhook_events' do
    context 'when there are custom supported events' do
      it 'returns the default and custom events' do
        all_webhook_events = Spree::Order.default_webhook_events + Spree::Order.custom_webhook_events
        expect(Spree::Order.supported_webhook_events).to contain_exactly(*all_webhook_events)
      end
    end

    context 'when there are no custom supported events' do
      it 'return the default events' do
        expect(Spree::Zone.supported_webhook_events).to eq(Spree::Zone.default_webhook_events)
      end
    end
  end
end
