require 'spec_helper'

describe Spree::Webhooks::HasWebhooks do
  before do
    allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
    allow(queue_requests).to receive(:call).with(any_args)
  end

  after { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

  let(:images) { create_list(:image, 2) }
  let(:product) do
    build(
      :product_in_stock,
      variants_including_master: [create(:variant, images: images), build(:variant)],
      stores: [store]
    )
  end
  let(:store) { create(:store) }
  let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }

  context 'with DISABLE_SPREE_WEBHOOKS equals "true" (set in spec_helper)' do
    before { product.save }

    context 'after_create_commit' do
      it 'does not queue a request' do
        expect(queue_requests).not_to have_received(:call).with(hash_including(event: 'product.create'))
      end
    end

    context 'after_destroy_commit' do
      it 'does not queue a request' do
        product.destroy
        expect(queue_requests).not_to have_received(:call).with(hash_including(event: 'product.destroy'))
      end
    end

    context 'after_update_commit' do
      it 'does not queue a request' do
        product.update(name: 'updated')
        expect(queue_requests).not_to have_received(:call).with(hash_including(event: 'product.update'))
      end
    end
  end

  context 'without DISABLE_SPREE_WEBHOOKS' do
    let(:body) { Spree::Api::V2::Platform::ProductSerializer.new(product).serializable_hash.to_json }

    before do
      ENV['DISABLE_SPREE_WEBHOOKS'] = nil
      product.save
    end

    context 'after_create_commit' do
      it 'queues a request through QueueRequests for product.create' do
        expect(queue_requests).to have_received(:call).with(event: 'product.create', body: body).once
      end
    end

    context 'after_destroy_commit' do
      it 'queues a request through QueueRequests for product.destroy' do
        product.destroy
        expect(queue_requests).to have_received(:call).with(event: 'product.destroy', body: body).once
      end
    end

    context 'after_update_commit' do
      it 'queues a request through QueueRequests for product.update' do
        product.update(name: 'updated')
        expect(queue_requests).to have_received(:call).with(event: 'product.update', body: body).once
      end
    end

    context 'with a class name with multiple words' do
      let!(:cms_page) { create(:cms_homepage, store: store, locale: 'en') }
      let(:body) do
        Spree::Api::V2::Platform::CmsPageSerializer.new(cms_page).serializable_hash.to_json
      end
      let(:underscore_event) { 'cms_page.create' }

      it 'underscorize the event name' do
        expect(queue_requests).to have_received(:call).with(event: underscore_event, body: body).once
      end
    end
  end
end
