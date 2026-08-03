require 'spec_helper'
require 'rake'

describe 'spree:upgrade:backfill_product_tag_tenants' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:backfill_product_tag_tenants' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'product_tag_tenants.rake')
  end

  before { subject.reenable }

  let!(:store) { Spree::Store.default || create(:store, default: true) }
  let!(:product) { create(:product, store: store, tag_list: ['eco']) }

  def tagging_for(taggable)
    ActsAsTaggableOn::Tagging.find_by(taggable: taggable, context: 'tags')
  end

  def downgrade!(tagging)
    tagging.update_columns(tenant: nil)
    tagging
  end

  context 'product tagging created before the tenant backfill' do
    let!(:tagging) { downgrade!(tagging_for(product)) }

    it "backfills tenant from the product's store_id" do
      expect { subject.invoke }.to change { tagging.reload.tenant }.from(nil).to(store.id.to_s)
    end

    it 'is idempotent' do
      subject.invoke
      subject.reenable
      expect { subject.invoke }.not_to change { tagging.reload.tenant }
    end
  end

  context 'orphaned tagging whose product no longer exists' do
    let(:tag) { ActsAsTaggableOn::Tag.create!(name: 'orphan') }
    let!(:orphan) do
      tagging = ActsAsTaggableOn::Tagging.new(
        tag: tag, taggable_type: 'Spree::Product', taggable_id: 0, context: 'tags', tenant: nil
      )
      tagging.save!(validate: false) # taggable presence is validated; forge a row pointing at a deleted product
      tagging
    end

    it 'leaves tenant nil (the store_id subquery resolves to NULL)' do
      expect { subject.invoke }.not_to change { orphan.reload.tenant }.from(nil)
    end
  end
end
