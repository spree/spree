require 'spec_helper'

# Permission keys answer "may this admin touch products at all". They do not
# answer "which products". A host app narrows that with a record-level ability
# rule, the Admin API honours it, and so must the assistant — otherwise a
# seller asks the assistant and sees the whole store.
RSpec.describe 'assistant authorization' do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) { Spree::AgentTools::Context.new(store: store, user: admin, ability: ability) }

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
      result = Spree::AgentTools::SearchResources.new(context).call(resource: 'products', limit: 25)
      titles = result[:records].map { |record| record[:title] }

      expect(titles).to include('Visible Product')
      expect(titles).not_to include('Hidden Product')
    end

    it 'counts only what the admin may see' do
      result = Spree::AgentTools::SearchResources.new(context).call(resource: 'products')

      # The assistant states this number out loud, so a leak here is a leak the
      # merchant reads.
      expect(result[:total]).to eq(1)
    end

    it 'cannot fetch an excluded record directly' do
      result = Spree::AgentTools::GetResource.new(context).
        call(resource: 'products', id: hidden.prefixed_id)

      expect(result[:error]).to be_present
      expect(result[:record]).to be_nil
    end
  end

  # The hand-written status tool is gone: the products workflows are tools by
  # the allowlist, so a change runs the same workflow the dashboard runs. What
  # the retired tool's specs asserted — that a record the ability excludes
  # cannot be changed, and one it includes can — is asserted here against the
  # workflow tool that replaced it.
  describe 'changes, through the workflow tool' do
    let(:tool) do
      Spree.agent_tools.available_for(context).find { |candidate| candidate.tool_name == 'products_draft' }
    end

    it 'refuses a record the ability excludes' do
      result = tool.call(product: hidden.prefixed_id)

      expect(result[:error]).to be_present
      expect(hidden.reload.status).to eq('active')
    end

    it 'allows a record the ability includes' do
      result = tool.call(product: visible.prefixed_id)

      expect(result[:error]).to be_nil
      expect(visible.reload.status).to eq('draft')
    end

    # A create workflow takes `store:`, and the principal is injected into
    # `created_by:`. Neither is something the caller named, so neither is what
    # the permission check is about — an order desk may cancel an order
    # without being allowed to "update" the store it belongs to or the user
    # they are signed in as.
    context 'when the workflow takes an injected store and principal' do
      let(:ability) do
        Class.new do
          include CanCan::Ability

          def initialize(*)
            can :manage, Spree::Product
            can :read, Spree::Store
          end

          def permission_keys
            %w[read_products write_products]
          end
        end.new
      end

      it 'creates without demanding permission over the store or the actor' do
        tool = Spree.agent_tools.available_for(context).find { |t| t.tool_name == 'products_create' }
        result = tool.call(attributes: { 'name' => "Agent Made #{SecureRandom.hex(3)}" })

        expect(result[:error]).to be_nil
        expect(result.dig(:record, :title)).to start_with('Agent Made')
      end

      it 'names the created record in the summary, not the store' do
        tool = Spree.agent_tools.available_for(context).find { |t| t.tool_name == 'products_create' }
        result = tool.call(attributes: { 'name' => 'Summary Subject' })

        expect(result[:summary]).to include('Summary Subject')
        expect(result[:summary]).not_to include(store.name)
      end
    end

    # The stock catalog grants writes as `:manage`, which covers deletion —
    # but an ability can be replaced, and a host app that grants `:update`
    # without `:destroy` means it. A deletion checked as an update would go
    # straight through.
    context 'when the admin may edit a product but not delete one' do
      let(:ability) do
        Class.new do
          include CanCan::Ability

          def initialize(*)
            can :read, Spree::Product
            can :update, Spree::Product
          end

          def permission_keys
            Spree.permissions.catalog_keys
          end
        end.new
      end

      it 'refuses the destroy workflow' do
        destroy = Spree.agent_tools.available_for(context).
                  find { |candidate| candidate.tool_name == 'products_destroy' }
        result = destroy.call(product: visible.prefixed_id)

        expect(result[:error]).to be_present
        expect(visible.reload).to be_present
      end

      it 'still allows the edit workflows' do
        result = tool.call(product: visible.prefixed_id)

        expect(result[:error]).to be_nil
      end
    end

    # The rule that matters, and the one a `can :manage` fixture hides:
    # reading every product and editing one is an ordinary shape for a
    # marketplace role, and a write tool that only checks readability would
    # let an agent change all of them.
    context 'when the admin may read every product but edit only one' do
      let(:ability) do
        Class.new do
          include CanCan::Ability

          def initialize(editable)
            can :read, Spree::Product
            can :update, Spree::Product, id: editable.id
          end

          def permission_keys
            Spree.permissions.catalog_keys
          end
        end.new(visible)
      end

      it 'refuses to change the one it may only read' do
        result = tool.call(product: hidden.prefixed_id)

        expect(result[:error]).to be_present
        expect(hidden.reload.status).to eq('active')
      end

      it 'still changes the one it may edit' do
        result = tool.call(product: visible.prefixed_id)

        expect(result[:error]).to be_nil
        expect(visible.reload.status).to eq('draft')
      end
    end
  end
end
