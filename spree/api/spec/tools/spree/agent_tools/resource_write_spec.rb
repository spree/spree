require 'spec_helper'

# The generic writes exist for the settings screens — the resources the Admin
# API saves directly. Everything else is written by its own workflow tool, and
# these have to say so rather than quietly doing it a second way.
RSpec.describe 'agent generic record writes' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key, request_headers: agent_headers_for_key(api_key)) }

  def tool(name)
    Spree.agent_tools.available_for(context).find { |candidate| candidate.tool_name == name }
  end

  describe 'update_resource' do
    let(:market) { store.markets.first || create(:market, store: store) }

    it 'persists a change through the model\'s own validations' do
      result = tool('update_resource').call(resource: 'markets', id: market.prefixed_id,
                                            attributes: { 'name' => 'Northern Europe' })

      expect(result[:error]).to be_nil
      expect(market.reload.name).to eq('Northern Europe')
    end

    it 'hands back the model\'s own message when it refuses' do
      result = tool('update_resource').call(resource: 'markets', id: market.prefixed_id,
                                            attributes: { 'name' => '' })

      expect(result[:error]).to be_present
      expect(market.reload.name).not_to eq('')
    end

    # A resource with a workflow has exactly one way to be written, and the
    # refusal names it so the model retries with the right tool instead of
    # giving up.
    # The old refusal rule is gone. It existed because the generic writes
    # assigned attributes and saved, which would have been a second way to
    # write the same record; dispatched, this IS the controller's way, and
    # the controller runs whatever workflow it declares.
    it 'writes a resource whose controller declares a workflow' do
      product = create(:product, store: store)

      result = tool('update_resource').call(resource: 'products', id: product.prefixed_id,
                                            attributes: { 'name' => 'Renamed' })

      expect(result[:error]).to be_nil
      expect(product.reload.name).to eq('Renamed')
    end

    it 'writes a resource whose controller calls a service' do
      order = create(:order, store: store)

      result = tool('update_resource').call(resource: 'orders', id: order.prefixed_id,
                                            attributes: { 'email' => 'new@example.com' })

      expect(result[:error]).to be_nil
      expect(order.reload.email).to eq('new@example.com')
    end

    # Silently dropping an attribute leaves the model believing it set
    # something it did not; naming the real ones lets it correct itself.
    it 'names the accepted attributes when given one it does not know' do
      result = tool('update_resource').call(resource: 'markets', id: market.prefixed_id,
                                            attributes: { 'colour' => 'blue' })

      expect(result[:error]).to include('colour')
      expect(result[:accepted_attributes]).to include('currency')
    end

    it 'does not reach another store\'s record' do
      other = create(:market, store: create(:store, code: "other-#{SecureRandom.hex(4)}"))

      result = tool('update_resource').call(resource: 'markets', id: other.prefixed_id,
                                            attributes: { 'name' => 'Taken Over' })

      expect(result[:error]).to be_present
      expect(other.reload.name).not_to eq('Taken Over')
    end

    it 'refuses an unknown resource' do
      result = tool('update_resource').call(resource: 'unicorns', id: 'x', attributes: {})

      expect(result[:error]).to include('unicorns')
    end
  end

  describe 'create_resource' do
    # Built through the store's own association, so the record carries its
    # tenancy from where it was built rather than from an attribute the caller
    # could have named.
    it 'creates the record in the caller\'s store' do
      name = "Northern #{SecureRandom.hex(3)}"

      result = tool('create_resource').call(
        resource: 'markets',
        attributes: { 'name' => name, 'currency' => 'EUR', 'default_locale' => 'en', 'country_codes' => ['DE'] }
      )

      expect(result[:error]).to be_nil
      expect(Spree::Market.for_store(store).where(name: name)).to exist
    end

    it 'creates a resource whose controller declares a workflow' do
      result = tool('create_resource').call(resource: 'products',
                                            attributes: { 'name' => "Dispatched #{SecureRandom.hex(3)}" })

      expect(result[:error]).to be_nil
      expect(result[:record][:id]).to be_present
    end
  end

  # The write tools tell the caller to call describe_resource for the
  # attributes a resource accepts, so it has to answer that question.
  describe 'describe_resource and the write tools agree' do
    it 'lists the attributes a generic write accepts' do
      described = Spree.agent_tools.available_for(context).
                  find { |candidate| candidate.tool_name == 'describe_resource' }.
                  call(resource: 'markets')[:resources].first

      expect(described[:writable_attributes]).to include('name', 'currency')
    end

    it 'names the create and update tools separately' do
      described = Spree.agent_tools.available_for(context).
                  find { |candidate| candidate.tool_name == 'describe_resource' }.
                  call(resource: 'products')[:resources].first

      expect(described[:created_by_tool]).to eq('products_create')
      expect(described[:updated_by_tool]).to eq('products_update')
      # Reported now where it used to be withheld: the generic writes reach
      # the controller, so a resource with a workflow is writable through
      # them too and the model needs its attribute list either way.
      expect(described[:writable_attributes]).to include('name')
    end
  end

  # A create body can carry a parameter the controller translates rather than
  # assigns — a delivery profile's `kind` picks the STI subclass and is not a
  # column. The old generic write handed it to `assign_attributes` and had to
  # catch the raise; dispatched, the controller decides what to do with it,
  # so the whole class of problem belongs to the endpoint.
  describe 'an attribute the controller translates rather than assigns' do
    let(:profile) { store.delivery_profiles.first || create(:delivery_profile, store: store) }

    it 'leaves it to the endpoint rather than raising' do
      result = tool('update_resource').call(resource: 'delivery_profiles', id: profile.prefixed_id,
                                            attributes: { 'kind' => 'shipping' })

      expect(result[:error]).to be_nil
    end

    it 'applies the attributes alongside it' do
      result = tool('update_resource').call(resource: 'delivery_profiles', id: profile.prefixed_id,
                                            attributes: { 'name' => 'Renamed Profile', 'kind' => 'shipping' })

      expect(result[:error]).to be_nil
      expect(profile.reload.name).to eq('Renamed Profile')
    end
  end

  describe 'what a read-only key is offered' do
    let(:api_key) { create(:api_key, :secret, store: store, scopes: ['read_all']) }

    it 'is not offered the write tools at all' do
      names = Spree.agent_tools.available_for(context).map(&:tool_name)

      expect(names).not_to include('create_resource', 'update_resource', 'delete_resource')
    end
  end
end
