require 'spec_helper'
require 'rake'

describe 'spree:upgrade:backfill_actor_types' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:backfill_actor_types' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'backfill_actor_types.rake')
  end

  before { subject.reenable }

  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:admin_user_type) { Spree.admin_user_class.to_s }

  # What a row written before the type column existed looks like.
  def strip_type!(record, name)
    record.class.where(id: record.id).update_all(:"#{name}_type" => nil)
    record.reload
  end

  it 'names the admin user class on an order that had only an id' do
    order = create(:order, store: store, canceler: admin_user)
    strip_type!(order, :canceler)

    subject.invoke

    expect(order.reload.canceler_type).to eq(admin_user_type)
  end

  it 'covers every model that declares an actor' do
    receipt = create(:stock_receipt, received_by: admin_user)
    strip_type!(receipt, :received_by)

    subject.invoke

    expect(receipt.reload.received_by_type).to eq(admin_user_type)
  end

  it 'leaves an actor that is already named alone' do
    key = create(:api_key, :secret, store: store)
    order = create(:order, store: store, canceler: key)

    subject.invoke

    expect(order.reload.canceler_type).to eq('Spree::ApiKey')
    expect(order.canceler).to eq(key)
  end

  it 'leaves a row with no actor alone' do
    order = create(:order, store: store)

    subject.invoke

    expect(order.reload.canceler_type).to be_nil
    expect(order.canceler_id).to be_nil
  end

  it 'is idempotent' do
    order = create(:order, store: store, canceler: admin_user)
    strip_type!(order, :canceler)

    subject.invoke
    subject.reenable
    expect { subject.invoke }.not_to change { order.reload.canceler_type }
  end

  it 'stops the transitional reader from warning' do
    order = create(:order, store: store, canceler: admin_user)
    strip_type!(order, :canceler)

    subject.invoke

    expect(Spree::Deprecation).not_to receive(:warn)
    expect(order.reload.canceler).to eq(admin_user)
  end
end
