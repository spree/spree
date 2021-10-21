require 'spec_helper'

module Spree
  module Webhooks
    class TestProduct < ActiveRecord::Base
      self.table_name = 'test_products'

      include Spree::Webhooks::HasWebhooks
    end
  end
end

module Spree
  class TestProduct < ActiveRecord::Base
    self.table_name = 'test_products'

    include Spree::Webhooks::HasWebhooks
  end
end

describe Spree::Webhooks::HasWebhooks do
  before(:all) do
    ActiveRecord::Base.connection.create_table :test_products, force: true do |t|
      t.string :name
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :test_products, if_exists: true
  end

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
    context 'with a Spree::Webhooks descendant class' do
      let(:product) { Spree::Webhooks::TestProduct.new(name: 'test') }

      before do
        ENV['DISABLE_SPREE_WEBHOOKS'] = nil
        product.save
      end

      context 'after_create_commit' do
        it 'does not queue a request' do
          expect(queue_requests).not_to have_received(:call).with(hash_including(event: 'test_product.create'))
        end
      end

      context 'after_destroy_commit' do
        it 'does not queue a request' do
          product.destroy
          expect(queue_requests).not_to have_received(:call).with(hash_including(event: 'test_product.destroy'))
        end
      end

      context 'after_update_commit' do
        it 'does not queue a request' do
          product.update(name: 'updated')
          expect(queue_requests).not_to have_received(:call).with(hash_including(event: 'test_product.update'))
        end
      end
    end

    context 'without a Spree::Webhooks descendant class' do
      context 'with a resource serializer' do
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

      context 'without a resource serializer' do
        let(:product) { Spree::TestProduct.new(name: 'test') }

        let(:exception_msg) { /uninitialized constant Spree::Api::V2::Platform::TestProductSerializer/ }

        context 'after_create_commit' do
          before { ENV['DISABLE_SPREE_WEBHOOKS'] = nil }

          it { expect { product.save }.to raise_error(NameError, exception_msg) }
        end

        context 'update/destroy' do
          before do
            ENV['DISABLE_SPREE_WEBHOOKS'] = 'true'
            product.save
            ENV['DISABLE_SPREE_WEBHOOKS'] = nil
          end

          context 'after_destroy_commit' do
            it { expect { product.destroy }.to raise_error(NameError, exception_msg) }
          end

          context 'after_update_commit' do
            it { expect { product.update(name: 'new name') }.to raise_error(NameError, exception_msg) }
          end
        end
      end
    end
  end
end
