require 'spec_helper'

module Spree
  TestOrder = Struct.new(:adjustment_total, :id, :item_total, :outstanding_balance, keyword_init: true) do
    extend Spree::DisplayMoney

    money_methods :adjustment_total, :item_total, :outstanding_balance

    # Just for testing setter methods aren't added
    def display_item_total=
    end

    def self.json_api_type
      to_s.demodulize.underscore
    end

    def self.json_api_columns
      %w[created_at updated_at]
    end
  end

  module Api
    module V2
      module Platform
        class TestOrderSerializer < ::Spree::Api::V2::BaseSerializer
          include Spree::Api::V2::ResourceSerializerConcern
        end
      end
    end
  end
end

describe Spree::Api::V2::ResourceSerializerConcern do
  describe '.included' do
    let(:adjustment_total) { 100.0 }
    let(:created_at) { 1.day.ago }
    let(:id) { 1 }
    let(:item_total) { 110.0 }
    let(:outstanding_balance) { 10.0 }
    let(:serializable_hash) { Spree::Api::V2::Platform::TestOrderSerializer.new(test_order).serializable_hash }
    let(:test_order) do
      Spree::TestOrder.new(
        adjustment_total: adjustment_total,
        id: id,
        item_total: item_total,
        outstanding_balance: outstanding_balance
      )
    end
    let(:updated_at) { Time.now }

    before { allow(test_order).to receive_messages(created_at: created_at, updated_at: updated_at) }

    it do
      expect(serializable_hash).to(
        eq(
          data: {
            id: test_order.id.to_s,
            type: :test_order,
            attributes: {
              created_at: created_at,
              display_adjustment_total: test_order.display_adjustment_total.to_s,
              display_item_total: test_order.display_item_total.to_s,
              display_outstanding_balance: test_order.display_outstanding_balance.to_s,
              updated_at: updated_at
            }
          }
        )
      )
    end

    it 'sets the base type' do
      expect(serializable_hash[:data][:type]).to eq(:test_order)
    end

    it 'adds the model class json_api_columns as attributes' do
      expect(serializable_hash[:data][:attributes][:created_at]).to eq(created_at)
      expect(serializable_hash[:data][:attributes][:updated_at]).to eq(updated_at)
    end

    it 'adds all the display instance methods the class has' do
      expect(serializable_hash[:data][:attributes].key?(:display_adjustment_total)).to eq(true)
      expect(serializable_hash[:data][:attributes].key?(:display_item_total)).to eq(true)
      expect(serializable_hash[:data][:attributes].key?(:display_outstanding_balance)).to eq(true)
    end

    it 'converts to string the display money attributes' do
      expect(serializable_hash[:data][:attributes][:display_outstanding_balance]).to(
        eq(test_order.display_outstanding_balance.to_s)
      )
      expect(serializable_hash[:data][:attributes][:display_adjustment_total]).to(
        eq(test_order.display_adjustment_total.to_s)
      )
      expect(serializable_hash[:data][:attributes][:display_item_total]).to(
        eq(test_order.display_item_total.to_s)
      )
    end

    it 'does not add display setter methods - ending with "="' do
      expect(serializable_hash[:data][:attributes].key?(:display_item_total=)).to eq(false)
    end

    context 'when model class is a Spree::Product' do
      context 'display_amount method' do
        let(:product) { create(:product) }
        let(:serializable_hash) { Spree::Api::V2::Platform::ProductSerializer.new(product).serializable_hash }

        it 'does not add the display_amount method' do
          expect(serializable_hash[:data][:attributes].key?(:display_amount)).to eq(false)
        end
      end
    end

    context 'when model class is a Spree::Variant' do
      context 'display_amount method' do
        let(:variant) { create(:variant) }
        let(:serializable_hash) { Spree::Api::V2::Platform::VariantSerializer.new(variant).serializable_hash }

        it 'does not add the display_amount method' do
          expect(serializable_hash[:data][:attributes].key?(:display_amount)).to eq(false)
        end
      end
    end
  end
end
