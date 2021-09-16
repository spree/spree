require 'spec_helper'

module Test
  class Product < ActiveRecord::Base
    self.table_name = 'test_products'

    include Spree::Webhooks::HasWebhooks
  end
end

module Spree
  class Webhooks::Product < ActiveRecord::Base
    self.table_name = 'test_products'

    include Spree::Webhooks::HasWebhooks
  end
end

describe Spree::Webhooks::HasWebhooks do
  let(:connection) { ActiveRecord::Base.connection }
  let(:url) { 'https://google.com' }

  before do
    stub_request(:any, url)
    connection.create_table :test_products, force: true do |table|
      table.string :name
    end
  end

  after do
    connection.drop_table :test_products, if_exists: true
  end

  context 'with a Spree::Webhooks class including the module' do
    let!(:product) { Spree::Webhooks::Product.create(name: 'test') }

    context 'after commit on create' do
      it 'does not execute the webhook callback' do
        expect(Spree::Webhooks::Endpoints::QueueRequests).not_to(receive(:new))
      end
    end

    context 'after commit on destroy' do
      it 'does not execute the webhook callback' do
        product.destroy
        expect(Spree::Webhooks::Endpoints::QueueRequests).not_to(receive(:new))
      end
    end

    context 'after commit on update' do
      it 'does not execute the webhook callback' do
        product.update(name: 'updated')
        expect(Spree::Webhooks::Endpoints::QueueRequests).not_to(receive(:new))
      end
    end
  end

  context 'with a non Spree::Webhooks class including the module' do
    let(:product) { Test::Product.create(name: 'test') }

    context 'after commit on create' do
      it 'executes the webhook callback' do
        expect(Spree::Webhooks::Endpoints::QueueRequests).to(
          receive(:new).once.and_return(
            double(:new).tap do |scope|
              expect(scope).to receive(:call).with(event: 'product.create').once
            end
          )
        )
        product
      end
    end

    context 'after commit on destroy' do
      before { product }

      it 'executes the webhook callback' do
        expect(Spree::Webhooks::Endpoints::QueueRequests).to(
          receive(:new).once.and_return(
            double(:new).tap do |scope|
              expect(scope).to receive(:call).with(event: 'product.destroy').once
            end
          )
        )
        product.destroy
      end
    end

    context 'after commit on update' do
      before { product }

      it 'executes the webhook callback' do
        expect(Spree::Webhooks::Endpoints::QueueRequests).to(
          receive(:new).once.and_return(
            double(:new).tap do |scope|
              expect(scope).to receive(:call).with(event: 'product.update').once
            end
          )
        )
        product.update(name: 'updated')
      end
    end
  end
end
