require 'spec_helper'
require 'fileutils'
require 'rails/generators'
require 'generators/spree/subscriber/subscriber_generator'

RSpec.describe Spree::SubscriberGenerator, type: :generator do
  let(:destination) { File.expand_path('../../../../../tmp/subscriber_generator_test', __dir__) }

  before do
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)
  end

  after do
    FileUtils.rm_rf(destination)
  end

  def run_generator(argv)
    described_class.start(argv, destination_root: destination)
  end

  def read(relative)
    path = File.join(destination, relative)
    File.exist?(path) && File.read(path)
  end

  it 'generates a subscriber with the events and a handle method' do
    run_generator(['OmsOrderSync', 'order.completed', 'order.canceled'])

    subscriber = read('app/subscribers/oms_order_sync_subscriber.rb')
    expect(subscriber).to include('class OmsOrderSyncSubscriber < Spree::Subscriber')
    expect(subscriber).to include("subscribes_to 'order.completed', 'order.canceled'")
    expect(subscriber).to include('def handle(event)')
  end

  it 'does not double the Subscriber suffix' do
    run_generator(['OmsOrderSyncSubscriber', 'order.completed'])

    expect(read('app/subscribers/oms_order_sync_subscriber.rb')).to include('class OmsOrderSyncSubscriber')
    expect(read('app/subscribers/oms_order_sync_subscriber.rb')).not_to include('SubscriberSubscriber')
  end

  it 'creates config/initializers/spree.rb with the registration when absent' do
    run_generator(['OmsOrderSync', 'order.completed'])

    initializer = read('config/initializers/spree.rb')
    expect(initializer).to include('Rails.application.config.after_initialize do')
    expect(initializer).to include('Spree.subscribers << OmsOrderSyncSubscriber')
  end

  it 'injects into an existing after_initialize block in spree.rb' do
    FileUtils.mkdir_p(File.join(destination, 'config/initializers'))
    File.write(File.join(destination, 'config/initializers/spree.rb'), <<~RUBY)
      Spree.config do |config|
        config.track_inventory_levels = true
      end

      Rails.application.config.after_initialize do
        Spree.dependencies.cart_add_item_service = 'MyApp::AddItem'
      end
    RUBY

    run_generator(['OmsOrderSync', 'order.completed'])

    initializer = read('config/initializers/spree.rb')
    expect(initializer).to include("Rails.application.config.after_initialize do\n  Spree.subscribers << OmsOrderSyncSubscriber")
    expect(initializer).to include('track_inventory_levels')
    expect(initializer.scan('after_initialize').size).to eq(1)
  end

  it 'appends a new after_initialize block when spree.rb has none' do
    FileUtils.mkdir_p(File.join(destination, 'config/initializers'))
    File.write(File.join(destination, 'config/initializers/spree.rb'), <<~RUBY)
      Spree.config do |config|
        config.track_inventory_levels = true
      end
    RUBY

    run_generator(['OmsOrderSync', 'order.completed'])

    initializer = read('config/initializers/spree.rb')
    expect(initializer).to include('track_inventory_levels')
    expect(initializer).to include('Rails.application.config.after_initialize do')
    expect(initializer).to include('Spree.subscribers << OmsOrderSyncSubscriber')
  end

  it 'appends to an existing initializer without duplicating registrations' do
    run_generator(['OmsOrderSync', 'order.completed'])
    run_generator(['BrandSync', 'brand.created'])
    run_generator(['OmsOrderSync', 'order.completed'])

    initializer = read('config/initializers/spree.rb')
    expect(initializer.scan('Spree.subscribers << OmsOrderSyncSubscriber').size).to eq(1)
    expect(initializer).to include('Spree.subscribers << BrandSyncSubscriber')
  end

  it 'supports namespaced subscribers with nested modules' do
    run_generator(['MyApp::BrandSync', 'brand.created'])

    subscriber = read('app/subscribers/my_app/brand_sync_subscriber.rb')
    expect(subscriber).to include("module MyApp\n  class BrandSyncSubscriber < Spree::Subscriber")
    expect(read('config/initializers/spree.rb')).to include('Spree.subscribers << MyApp::BrandSyncSubscriber')
  end

  it 'adds async: false with --sync' do
    run_generator(['CriticalSync', 'order.completed', '--sync'])

    expect(read('app/subscribers/critical_sync_subscriber.rb')).to include("subscribes_to 'order.completed', async: false")
  end

  it 'emits a TODO placeholder when no events are given' do
    run_generator(['Mystery'])

    expect(read('app/subscribers/mystery_subscriber.rb')).to include("subscribes_to 'TODO.replace_with_event_name'")
  end

  it 'generates a spec file unless --skip-spec' do
    run_generator(['OmsOrderSync', 'order.completed'])
    expect(read('spec/subscribers/oms_order_sync_subscriber_spec.rb')).to include('RSpec.describe OmsOrderSyncSubscriber')

    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)
    run_generator(['OmsOrderSync', 'order.completed', '--skip-spec'])
    expect(read('spec/subscribers/oms_order_sync_subscriber_spec.rb')).to be(false)
  end
end
