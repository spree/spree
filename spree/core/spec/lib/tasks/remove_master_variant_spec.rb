require 'spec_helper'
require 'rake'

describe 'spree:remove_master_variant' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:remove_master_variant' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'remove_master_variant.rake')
  end

  before { subject.reenable }

  # Resolve the master by the is_master column — Product#master becomes a
  # deprecated alias for default_variant later, so the spec must not call it.
  def master_for(product)
    Spree::Variant.with_deleted.find_by(product_id: product.id, is_master: true)
  end

  # The computed Product#default_variant_id method shadows the attribute reader,
  # so read the raw column to assert on the persisted value.
  def persisted_default_variant_id(product)
    product.reload[:default_variant_id]
  end

  # Build the pre-migration shape — one is_master variant plus `extra` non-master
  # variants — without depending on what the factory's lone auto-variant happens
  # to be (a master today, a default variant after the factory is updated) or on
  # default_variant_id being unset.
  def legacy_product(extra: 0)
    product = create(:product)
    Spree::Variant.where(product_id: product.id).first.update_column(:is_master, true)
    product.update_column(:default_variant_id, nil)
    extra.times { create(:variant, product: product) }
    # Legacy rows counted variant_count under the old master-excluded rule. Mirror
    # that so the task must recompute correctly: deleting the master fires the
    # counter callback (out-of-band decrement) and a stale-value guard would leave
    # variant_count one short — matching this legacy baseline is what surfaces it.
    product.update_column(:variant_count, Spree::Variant.where(product_id: product.id, is_master: false).count)
    product
  end

  shared_examples 'an idempotent migration' do
    it 'leaves default_variant_id and variant_count unchanged on re-run' do
      subject.invoke
      default_variant_id = persisted_default_variant_id(product)
      variant_count = product.reload.variant_count

      subject.reenable
      subject.invoke

      expect(persisted_default_variant_id(product)).to eq(default_variant_id)
      expect(product.reload.variant_count).to eq(variant_count)
    end
  end

  context 'simple product (master only)' do
    let!(:product) { legacy_product }
    let!(:master_id) { master_for(product).id }

    it 'converts the master into a regular variant and points default_variant_id at it' do
      subject.invoke

      expect(Spree::Variant.find(master_id).is_master).to be(false)
      expect(persisted_default_variant_id(product)).to eq(master_id)
      expect(product.reload.variant_count).to eq(1)
    end

    it_behaves_like 'an idempotent migration'
  end

  context 'product with real variants and a ghost master' do
    let!(:product) { legacy_product(extra: 1) }
    let!(:master_id) { master_for(product).id }
    let!(:real_variant) { Spree::Variant.where(product_id: product.id, is_master: false).order(:position).first }

    it 'deletes the master and points default_variant_id at the first variant' do
      subject.invoke

      expect(Spree::Variant.with_deleted.exists?(master_id)).to be(false)
      expect(persisted_default_variant_id(product)).to eq(real_variant.id)
      expect(product.reload.variant_count).to eq(1)
    end

    it_behaves_like 'an idempotent migration'
  end

  context 'master that still carries line items' do
    let!(:product) { legacy_product(extra: 1) }
    let!(:master_id) { master_for(product).id }
    let!(:real_variant) { Spree::Variant.where(product_id: product.id, is_master: false).order(:position).first }

    # The master is a stripped ghost (the real variant cleared its stock), so a
    # current line item can't validate — model a historical order line instead.
    let!(:line_item) do
      order = create(:order)

      line_item = Spree::LineItem.new(
        order: order,
        variant: master_for(product),
        quantity: 1,
        price: 10,
        currency: order.currency
      )
      line_item.save!(validate: false)
      line_item
    end

    it 'keeps the master as a regular variant instead of deleting it' do
      subject.invoke

      expect(Spree::Variant.exists?(master_id)).to be(true)
      expect(Spree::Variant.find(master_id).is_master).to be(false)
      expect(persisted_default_variant_id(product)).to eq(real_variant.id)
    end

    it 'discontinues the kept master so it is not a live variant' do
      subject.invoke

      expect(Spree::Variant.find(master_id)).to be_discontinued
    end

    it_behaves_like 'an idempotent migration'
  end
end
