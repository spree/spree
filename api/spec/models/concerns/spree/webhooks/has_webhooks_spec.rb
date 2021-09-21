require 'spec_helper'

module Spree
  class Webhooks::Product < ActiveRecord::Base
    self.table_name = 'test_products'

    include Spree::Webhooks::HasWebhooks
  end
end

describe Spree::Webhooks::HasWebhooks do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.create_table :test_products, force: true do |t|
      t.string :name
    end
  end

  after do
    connection.drop_table :test_products, if_exists: true
  end

  context 'with a Spree::Webhooks class including the module' do
    let!(:product) { Spree::Webhooks::Product.create(name: 'test') }

    context 'after commit on create' do
      it 'does not execute the webhook callback' do
        expect(Spree::Webhooks::Endpoints::QueueRequests).not_to receive(:new)
      end
    end

    context 'after commit on destroy' do
      it 'does not execute the webhook callback' do
        product.destroy
        expect(Spree::Webhooks::Endpoints::QueueRequests).not_to receive(:new)
      end
    end

    context 'after commit on update' do
      it 'does not execute the webhook callback' do
        product.update(name: 'updated')
        expect(Spree::Webhooks::Endpoints::QueueRequests).not_to receive(:new)
      end
    end
  end

  context 'with a non Spree::Webhooks class including the module' do
    before do
      allow(Spree::Webhooks::Endpoints::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
    end

    context 'when able to infer the serializer from the class' do
      let!(:images) { create_list(:image, 2) }
      let!(:product) do
        create(
          :product_in_stock,
          variants_including_master: [create(:variant, images: images), build(:variant)]
        )
      end
      let(:payload) do
        Spree::Api::V2::Platform::ProductSerializer.new(
          product,
          params: { store: Spree::Store.default }
        ).serializable_hash
      end
      let(:queue_requests) { instance_double(Spree::Webhooks::Endpoints::QueueRequests) }

      context 'when the class name contains more than one word' do
        let(:product_property) { create(:product_property) }
        let(:payload) do
          Spree::Api::V2::Platform::ProductPropertySerializer.new(product_property).serializable_hash
        end

        it 'splits the words and joins them with an underscore to create the event_name' do
          expect(queue_requests).to have_received(:call).with(event: 'product_property.create', payload: payload).once
        end
      end

      context 'after commit on create' do
        it 'executes QueueRequests.call with a create event and the product serializer as the payload' do
          expect(queue_requests).to have_received(:call).with(event: 'product.create', payload: payload).once
        end
      end

      context 'after commit on destroy' do
        it 'executes QueueRequests.call with a destroy event and the product serializer as the payload' do
          product.destroy
          expect(queue_requests).to have_received(:call).with(event: 'product.destroy', payload: payload).once
        end
      end

      context 'after commit on update' do
        it 'executes QueueRequests.call with an update event and the product serializer as the payload' do
          product.update(name: 'updated')
          expect(queue_requests).to have_received(:call).with(event: 'product.update', payload: payload).once
        end
      end
    end

    context 'when unable to infer the serializer from the class' do
      let(:queue_requests) { instance_double(Spree::Webhooks::Endpoints::QueueRequests) }
      let!(:shipment) { create(:shipment) }

      context 'after commit on create' do
        it 'does not queue HTTP requests' do
          expect(queue_requests).not_to have_received(:call).with(hash_including(event: 'shipment.create'))
        end
      end

      context 'after commit on destroy' do
        it 'does not queue HTTP requests' do
          shipment.destroy
          expect(queue_requests).not_to have_received(:call).with(hash_including(event: 'shipment.destroy'))
        end
      end

      context 'after commit on update' do
        it 'does not queue HTTP requests' do
          shipment.update(tracking: 'U10001')
          expect(queue_requests).not_to have_received(:call).with(hash_including(event: 'shipment.update'))
        end
      end
    end
  end
end
