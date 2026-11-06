require 'spec_helper'

# create_export tells the agent to read the export back with get_resource, so
# exports and imports have to answer the generic read, list and delete tools
# like any other resource.
RSpec.describe 'agent tools on exports and imports' do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) do
    Spree::AgentTools::Context.new(store: store, user: admin, ability: ability,
                                   request_headers: agent_headers_for(admin))
  end
  let(:ability) do
    Class.new do
      include CanCan::Ability

      def initialize = can(:manage, :all)
      def permission_keys = Spree.permissions.catalog_keys
    end.new
  end

  def tool(name)
    Spree.admin_agent_tools.available_for(context).find { |candidate| candidate.tool_name == name }
  end

  describe 'exports' do
    let!(:export) { create(:product_export, store: store, user: admin) }

    it 'fetches the export create_export just made, with its state' do
      created = tool('create_export').call(resource: 'products', filters: { 'out_of_stock' => true })

      result = tool('get_resource').call(resource: 'exports', id: created[:id])

      expect(result[:error]).to be_nil
      expect(result[:record]['id']).to eq(created[:id])
      expect(result[:record]).to have_key('done')
    end

    it 'lists the exports' do
      result = tool('search_resources').call(resource: 'exports')

      expect(result[:error]).to be_nil
      expect(result[:records].pluck(:id)).to include(export.prefixed_id)
    end

    it 'deletes an export' do
      result = tool('delete_resource').call(resource: 'exports', id: export.prefixed_id)

      expect(result[:error]).to be_nil
      expect(Spree::Export.exists?(export.id)).to be(false)
    end
  end

  describe 'imports' do
    let!(:import) { create(:product_import, store: store, user: admin) }

    it 'fetches an import' do
      result = tool('get_resource').call(resource: 'imports', id: import.prefixed_id)

      expect(result[:error]).to be_nil
      expect(result[:record]['id']).to eq(import.prefixed_id)
    end

    it 'lists the imports' do
      result = tool('search_resources').call(resource: 'imports')

      expect(result[:error]).to be_nil
      expect(result[:records].pluck(:id)).to include(import.prefixed_id)
    end

    it 'deletes an import' do
      result = tool('delete_resource').call(resource: 'imports', id: import.prefixed_id)

      expect(result[:error]).to be_nil
      expect(Spree::Import.exists?(import.id)).to be(false)
    end
  end

  # Creating one is a typed request the dedicated tools build; the generic
  # create would send a body the endpoint cannot read.
  it 'leaves creating them to create_export and create_import' do
    %w[exports imports].each do |key|
      result = tool('create_resource').call(resource: key, attributes: { 'type' => 'products' })

      expect(result[:error]).to include("#{key} cannot be created this way")
    end
  end
end
