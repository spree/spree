require 'spec_helper'

# Permission keys answer "may this admin touch products at all". They do not
# answer "which products". A host app narrows that with a record-level ability
# rule, the Admin API honours it, and so must the assistant — otherwise a
# seller asks the assistant and sees the whole store.
RSpec.describe 'assistant authorization' do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) { Spree::Assistant::Context.new(store: store, user: admin, ability: ability) }

  let!(:visible) { create(:product, store: store, name: 'Visible Product', status: 'active') }
  let!(:hidden) { create(:product, store: store, name: 'Hidden Product', status: 'active') }

  # Stands in for a host app's record-level rule: this admin may see and edit
  # one product, not the other.
  let(:ability) do
    Class.new do
      include CanCan::Ability

      def initialize(allowed)
        can :manage, Spree::Product, id: allowed.id
      end

      def permission_keys
        Spree.permissions.catalog_keys
      end
    end.new(visible)
  end

  describe 'reads' do
    it 'hides records the ability excludes' do
      result = Spree::Assistant::Tools::SearchResources.new(context).call(resource: 'products', limit: 25)
      titles = result[:records].map { |record| record[:title] }

      expect(titles).to include('Visible Product')
      expect(titles).not_to include('Hidden Product')
    end

    it 'counts only what the admin may see' do
      result = Spree::Assistant::Tools::SearchResources.new(context).call(resource: 'products')

      # The assistant states this number out loud, so a leak here is a leak the
      # merchant reads.
      expect(result[:total]).to eq(1)
    end

    it 'cannot fetch an excluded record directly' do
      result = Spree::Assistant::Tools::GetResource.new(context).
        call(resource: 'products', id: hidden.prefixed_id)

      expect(result[:error]).to be_present
      expect(result[:record]).to be_nil
    end
  end

  describe 'changes' do
    it 'refuses a record the ability excludes' do
      result = Spree::Assistant::Tools::UpdateProductStatus.new(context).
        call(id: hidden.slug, status: 'draft')

      expect(result[:error]).to be_present
      expect(hidden.reload.status).to eq('active')
    end

    it 'allows a record the ability includes' do
      result = Spree::Assistant::Tools::UpdateProductStatus.new(context).
        call(id: visible.slug, status: 'draft')

      expect(result[:ok]).to be(true)
      expect(visible.reload.status).to eq('draft')
    end
  end
end
