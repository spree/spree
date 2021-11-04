require 'spec_helper'

describe Spree::Webhooks::HasWebhooks do
  let(:images) { create_list(:image, 2) }
  let(:product) do
    build(
      :product_in_stock,
      variants_including_master: [create(:variant, images: images), build(:variant)],
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

    shared_examples 'not queueing an event request' do |event_to_emit|
      it { expect(queue_requests).not_to have_received(:call).with(hash_including(event: event_to_emit)) }
    end

    context 'after_create_commit' do
      it_behaves_like 'not queueing an event request', 'product.create'
    end

    context 'after_destroy_commit' do
      before { product.destroy }

      it_behaves_like 'not queueing an event request', 'product.create'
    end

    context 'after_update_commit' do
      before { product.update(name: 'updated') }

      it_behaves_like 'not queueing an event request', 'product.create'
    end
  end

  context 'without DISABLE_SPREE_WEBHOOKS' do
    let(:body) { Spree::Api::V2::Platform::ProductSerializer.new(product).serializable_hash.to_json }

    context 'after_create_commit' do
      it { expect { product.save }.to emit_webhook_event('product.create') }
    end

    context 'after_destroy_commit' do
      before { product.save }

      it { expect { product.destroy }.to emit_webhook_event('product.destroy') }
    end

    context 'after_update_commit' do
      before { product.save }

      it { expect { product.update(name: 'updated') }.to emit_webhook_event('product.update') }
    end

    context 'with a class name with multiple words' do
      let(:body) { Spree::Api::V2::Platform::CmsPageSerializer.new(cms_page).serializable_hash.to_json }
      let(:cms_page) { create(:cms_homepage, store: store, locale: 'en') }

      it 'underscorize the event name' do
        expect { cms_page }.to emit_webhook_event('cms_page.create')
      end
    end
  end
end
