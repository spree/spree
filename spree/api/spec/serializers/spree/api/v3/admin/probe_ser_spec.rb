require 'spec_helper'

RSpec.describe 'actor serializer probes' do
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:api_key) { create(:api_key, :secret, store: store, name: 'WMS') }

  def ser(order, expand: [])
    JSON.parse(Spree::Api::V3::Admin::OrderSerializer.new(order, params: { expand: expand }).serialize)
  end

  it 'P1: api key actor, unexpanded' do
    order = create(:order, store: store, canceler: api_key)
    j = ser(order)
    puts "canceler_id=#{j['canceler_id'].inspect} canceler_type=#{j['canceler_type'].inspect}"
  end

  it 'P2: api key actor, expanded' do
    order = create(:order, store: store, canceler: api_key)
    j = ser(order, expand: ['canceler'])
    puts "expanded canceler=#{j['canceler'].inspect}"
  end

  it 'P3: un-backfilled row, expanded' do
    order = create(:order, store: store)
    order.update_columns(canceler_id: admin_user.id, canceler_type: nil)
    order.reload
    allow(Spree::Deprecation).to receive(:warn)
    j = ser(order, expand: ['canceler'])
    puts "unbackfilled id=#{j['canceler_id'].inspect} type=#{j['canceler_type'].inspect} exp=#{j['canceler'].inspect}"
  end

  it 'P4: dangling actor id (actor row deleted)' do
    order = create(:order, store: store, canceler: api_key)
    Spree::ApiKey.where(id: api_key.id).delete_all
    order.reload
    j = ser(order, expand: ['canceler'])
    puts "dangling id=#{j['canceler_id'].inspect} type=#{j['canceler_type'].inspect} exp=#{j['canceler'].inspect}"
  end

  it 'P5: unregistered type written by hand' do
    order = create(:order, store: store)
    product = create(:product, stores: [store])
    order.update_columns(canceler_id: product.id, canceler_type: 'Spree::Product')
    order.reload
    j = ser(order, expand: ['canceler'])
    puts "rogue id=#{j['canceler_id'].inspect} type=#{j['canceler_type'].inspect} exp=#{j['canceler'].inspect}"
  end
end
