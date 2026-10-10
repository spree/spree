require 'spec_helper'

# Permission keys answer "may this admin touch products at all". They do not
# answer "which products". A host app narrows that with a record-level ability
# rule, the Admin API honours it, and so must the assistant — otherwise a
# seller asks the assistant and sees the whole store.
RSpec.describe 'assistant authorization' do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) { Spree::AgentTools::Context.new(store: store, user: admin, ability: ability,
                                   request_headers: agent_headers_for(admin)) }

  let!(:visible) { create(:product, store: store, name: 'Visible Product', status: 'active') }
  let!(:hidden) { create(:product, store: store, name: 'Hidden Product', status: 'active') }

  # Stands in for a host app's record-level rule. Declared on the real ability
  # class rather than injected into the context, because a dispatched tool
  # call builds its own ability from the credential — which is the point: the
  # rule the dashboard obeys is the rule agents obey, not a copy of it.
  let(:ability) { full_ability }
  let(:full_ability) { Spree::Dependencies.ability_class.constantize.new(admin, store: store) }

  # Defined once at load rather than built per example: a dispatched request
  # resolves the class by name through `Spree::Dependencies`, and an
  # anonymous class stubbed onto a constant inside `before` was not always
  # the one it found when the whole suite ran.
  # Keyed on the record's own id, not on its name: a rule matching
  # 'Hidden Product' also matched any leftover of that name another spec had
  # created, and then the example was asserting about the wrong record.
  class NarrowedTestAbility < Spree::Ability
    def initialize(user, options = {})
      super
      hidden_id = RSpec.current_example&.metadata&.dig(:hidden_product_id)
      cannot %i[read update destroy], Spree::Product, id: hidden_id if hidden_id
    end
  end

  before do
    RSpec.current_example.metadata[:hidden_product_id] = hidden.id
    # `Spree.ability_class` is what the controller calls, and it answers a
    # class rather than a name — stubbing `Spree::Dependencies.ability_class`
    # left the dispatched request building the default ability.
    allow(Spree).to receive(:ability_class).and_return(NarrowedTestAbility)
    allow(Spree::Dependencies).to receive(:ability_class).and_return('NarrowedTestAbility')
  end

  describe 'reads' do
    it 'hides records the ability excludes' do
      result = Spree::AgentTools::SearchResources.new(context).call(resource: 'products', limit: 25)
      titles = result[:records].map { |record| record[:title] }

      expect(titles).to include('Visible Product')
      expect(titles).not_to include('Hidden Product')
    end

    it 'counts only what the admin may see' do
      result = Spree::AgentTools::SearchResources.new(context).call(resource: 'products', limit: 25)
      titles = result[:records].map { |record| record[:title] }

      # The assistant states this number out loud, so a leak here is a leak
      # the merchant reads.
      expect(result[:total]).to eq(titles.size)
      expect(titles).not_to include('Hidden Product')
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

    # A create workflow builds its own record, so there is nothing to check
    # when the tool runs — the Admin API checks `:create` on a built record
    # before calling the workflow, and the tool has no equivalent unless it
    # authorizes against the class.
    context 'when the admin may edit products but not create one' do
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

      it 'refuses the create workflow' do
        create_tool = Spree.agent_tools.available_for(context).
                      find { |candidate| candidate.tool_name == 'products_create' }
        result = create_tool.call(attributes: { 'name' => 'Should Not Exist' })

        expect(result[:error]).to be_present
        expect(Spree::Product.for_store(store).where(name: 'Should Not Exist')).not_to exist
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
