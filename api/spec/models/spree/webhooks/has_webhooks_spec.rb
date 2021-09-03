require 'spec_helper'

module Spree
  describe Webhooks::HasSpreeWebhooks do
    before(:all) do
      ActiveRecord::Base.connection.create_table(:test_spree_products, force: true) do |table|
        table.string :name
      end
      Spree.const_set(
        "TestSpreeProduct", 
        Class.new(Spree::Base) do
          self.table_name = 'test_spree_products'

          has_spree_webhooks(on: :create)
        end
      )
    end

    it 'implements has_spree_webhooks' do
      expect(TestSpreeProduct).to respond_to(:has_spree_webhooks)
    end

    context 'after commit on :create' do
      let(:test_spree_product) { TestSpreeProduct.new(name: 'test') }

      it 'executes the webhook logic' do
        expect do
          test_spree_product.save
        end.to change { test_spree_product.name }.from('test').to('execute_webhook_logic!')
      end
    end
  end
end
