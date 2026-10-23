require 'spec_helper'
require 'rake'

describe 'spree:upgrade:backfill_tagging_tenants' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:backfill_tagging_tenants' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'backfill_tagging_tenants.rake')
  end

  before { subject.reenable }

  let(:product) { create(:product, store: create(:store), tag_list: ['summer']) }
  let(:user) { create(:user, tag_list: ['newsletter']) }

  # Simulates a bulk-added row from before the store was stamped on it.
  def unstamp!(record)
    record.taggings.update_all(tenant: nil)
  end

  it 'stamps a tagging with the store of its record' do
    unstamp!(product)

    subject.invoke

    expect(product.taggings.pluck(:tenant)).to eq([product.store_id.to_s])
  end

  it 'leaves a tagging of a record without a store tenant alone' do
    unstamp!(user)

    subject.invoke

    expect(user.taggings.pluck(:tenant)).to eq([nil])
  end

  it 'skips taggings that already carry a store' do
    product

    expect { subject.invoke }.to output(/Nothing to backfill/).to_stdout
  end
end
