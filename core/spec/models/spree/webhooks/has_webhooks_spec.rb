require 'spec_helper'

module Test
  class Product < ActiveRecord::Base
    self.table_name = 'test_products'

    include Spree::Webhooks::HasWebhooks
  end
end

module Spree
  module Webhooks
    class Product < ActiveRecord::Base
      self.table_name = 'test_products'

      include Spree::Webhooks::HasWebhooks
    end
  end
end

module Spree
  describe Webhooks::HasWebhooks do
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
      context 'after commit on create' do
        it 'does not execute the webhook callback' do
          Spree::Webhooks::Product.create(name: 'new product #1')
          expect(WebMock).to_not have_requested(:post, url)
        end
      end

      context 'after commit on destroy' do
        let(:test_product) { Spree::Webhooks::Product.create(name: 'test') }

        it 'does not execute the webhook callback' do
          test_product.destroy
          expect(WebMock).to_not have_requested(:post, url)
        end
      end

      context 'after commit on update' do
        let(:test_product) { Spree::Webhooks::Product.create(name: 'test') }

        it 'does not execute the webhook callback' do
          test_product.update(name: 'updated')
          expect(WebMock).to_not have_requested(:post, url)
        end
      end
    end

    context 'with a non Spree::Webhooks class including the module' do
      context 'after commit on create' do
        it 'executes the webhook callback' do
          Test::Product.create(name: 'new product #1')
          expect(WebMock).to(
            have_requested(:post, url).with(
              body: {foo: :bar}.to_json,
              headers: {'Content-Type' => 'application/json'}
            ).once
          )
        end
      end

      context 'after commit on destroy' do
        let(:test_product) { Test::Product.create(name: 'test') }

        it 'executes the webhook callback' do
          test_product.destroy
          expect(WebMock).to(
            have_requested(:post, url).with(
              body: {foo: :bar}.to_json,
              headers: {'Content-Type' => 'application/json'}
            ).twice
          )
        end
      end

      context 'after commit on update' do
        let(:test_product) { Test::Product.create(name: 'test') }

        it 'executes the webhook callback' do
          test_product.update(name: 'updated')
          expect(WebMock).to(
            have_requested(:post, url).with(
              body: {foo: :bar}.to_json,
              headers: {'Content-Type' => 'application/json'}
            ).twice
          )
        end
      end
    end
  end
end
