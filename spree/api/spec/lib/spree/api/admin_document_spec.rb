require 'spec_helper'

# Core's admin document merged with the one each extension ships. See
# docs/plans/6.0-agent-tools-from-openapi.md.
RSpec.describe Spree::Api::AdminDocument do
  let(:dir) { Dir.mktmpdir }
  let(:extension_path) { Pathname.new(dir).join('admin.yaml') }

  before do
    described_class.reset!
    allow(described_class).to receive(:extension_paths).and_return('my_extension' => extension_path)
  end

  after do
    described_class.reset!
    FileUtils.remove_entry(dir)
  end

  def write_extension(document)
    File.write(extension_path, { 'openapi' => '3.0.3' }.merge(document).to_yaml)
  end

  it 'adds an extension\'s operations to core\'s' do
    write_extension('paths' => { '/api/v3/admin/quotes/{id}/send' => { 'patch' => { 'summary' => 'Send a quote' } } })

    expect(described_class.document.dig('paths', '/api/v3/admin/quotes/{id}/send', 'patch', 'summary')).to eq('Send a quote')
    expect(described_class.source_of('/api/v3/admin/quotes/{id}/send', 'patch')).to eq('my_extension')
    expect(described_class.document.dig('paths', '/api/v3/admin/orders/{id}/cancel', 'patch')).to be_present
  end

  # A conflict is left out and reported, not raised: one extension's stale
  # document must not take every agent tool down with it.
  it 'keeps core\'s operation when an extension documents the same one' do
    write_extension('paths' => { '/api/v3/admin/orders/{id}/cancel' => { 'patch' => { 'summary' => 'Hijacked' } } })

    expect(described_class.document.dig('paths', '/api/v3/admin/orders/{id}/cancel', 'patch', 'summary')).to eq('Cancel an order')
    expect(described_class.conflicts).to include(a_string_including('PATCH /api/v3/admin/orders/{id}/cancel'))
  end

  it 'does not count a path\'s shared parameters as a conflict' do
    write_extension('paths' => { '/api/v3/admin/orders/{id}/cancel' => { 'parameters' => [{ 'name' => 'id', 'in' => 'path' }] } })

    expect(described_class.conflicts).to be_empty
  end

  it 'ignores a file that is not an OpenAPI document' do
    File.write(extension_path, %w[not a document].to_yaml)

    expect(described_class.document.dig('paths', '/api/v3/admin/orders/{id}/cancel', 'patch')).to be_present
  end

  it 'ignores a document whose operation is not an object' do
    write_extension('paths' => { '/api/v3/admin/widgets' => { 'patch' => 'broken' } })

    expect(described_class.document.dig('paths', '/api/v3/admin/widgets')).to be_nil
  end

  it 'ignores a document whose request body is not an object' do
    write_extension('paths' => { '/api/v3/admin/widgets' => { 'post' => { 'requestBody' => { 'content' => { 'application/json' => 'broken' } } } } })

    expect(described_class.document.dig('paths', '/api/v3/admin/widgets')).to be_nil
  end

  it 'ignores YAML that is not an OpenAPI document' do
    File.write(extension_path, { 'paths' => { '/api/v3/admin/widgets' => { 'patch' => {} } } }.to_yaml)

    expect(described_class.document.dig('paths', '/api/v3/admin/widgets')).to be_nil
  end

  it 'follows a parameter reference into the extension\'s components' do
    write_extension('components' => { 'parameters' => { 'WidgetId' => { 'name' => 'id', 'in' => 'path' } } })

    expect(described_class.resolve_parameter('$ref' => '#/components/parameters/WidgetId')['in']).to eq('path')
  end

  it "keeps core's filter table when an extension's app filters the record differently, without a conflict" do
    core_order = described_class.send(:read, described_class.send(:core_path)).dig('components', 'x-spree-filter-tables', 'Order')
    changed = core_order.merge('scopes' => core_order['scopes'].to_h.merge('email_cont' => 'text'))
    write_extension('components' => { 'x-spree-filter-tables' => { 'Order' => changed, 'Quote' => { 'attributes' => { 'number' => 'text' } } } })

    expect(described_class.document.dig('components', 'x-spree-filter-tables', 'Order')).to eq(core_order)
    expect(described_class.document.dig('components', 'x-spree-filter-tables', 'Quote')).to be_present
    expect(described_class.conflicts).to be_empty
  end

  it 'keeps core\'s component when an extension defines it differently' do
    write_extension('components' => { 'schemas' => { 'Order' => { 'type' => 'string' } } })

    expect(described_class.document.dig('components', 'schemas', 'Order', 'type')).to eq('object')
    expect(described_class.conflicts).to include(a_string_including('Order'))
  end
end
