require 'spec_helper'

RSpec.describe Spree::AgentTools::Context do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }

  # An OAuth grant lets a merchant hand an agent part of their own authority.
  # The grant has to be a ceiling: a merchant who consented to reading
  # products must not hand over everything their role happens to allow.
  describe 'a delegated grant' do
    subject(:context) do
      described_class.new(store: store, user: admin, granted_scopes: ['read_products'])
    end

    let(:unrestricted) { described_class.new(store: store, user: admin) }

    it 'narrows the permissions the user holds' do
      expect(unrestricted.permitted?('write_orders')).to be(true)
      expect(context.permitted?('write_orders')).to be(false)
      expect(context.permitted?('read_products')).to be(true)
    end

    it 'never widens them' do
      limited = described_class.new(
        store: store,
        user: create(:admin_user, :without_admin_role),
        granted_scopes: Spree.permissions.catalog_keys
      )

      expect(limited.permitted?('write_orders')).to be(false)
    end

    it 'refuses a record the grant does not cover' do
      product = build(:product, store: store)

      expect(context.can?(:show, product)).to be(true)
      # Being offered a read tool is not permission to write through it.
      expect(context.can?(:update, product)).to be(false)
    end

    it 'refuses a resource outside the granted scope entirely' do
      order = build(:order, store: store)

      expect(unrestricted.can?(:show, order)).to be(true)
      expect(context.can?(:show, order)).to be(false)
    end

    it 'offers only the tools the grant covers' do
      expect(Spree.agent_tools.available_for(context).size).
        to be < Spree.agent_tools.available_for(unrestricted).size
    end
  end

  # Without a grant the caller is the user acting directly, and the ability is
  # the whole answer — this is the dashboard assistant's path.
  describe 'no grant' do
    it 'leaves the user’s own authority untouched' do
      context = described_class.new(store: store, user: admin)

      expect(context.permitted?('write_orders')).to be(true)
      expect(context.can?(:update, build(:product, store: store))).to be(true)
    end
  end
end
