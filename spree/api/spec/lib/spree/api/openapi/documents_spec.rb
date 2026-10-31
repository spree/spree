require 'spec_helper'

RSpec.describe Spree::Api::OpenAPI::Documents do
  let(:gem_root) { described_class::GEM_ROOT }

  it 'packs every document into the gem once bundled' do
    described_class.bundle!
    gemspec = Dir.chdir(gem_root) { Gem::Specification.load('spree_api.gemspec') }

    expect(gemspec.files).to include('openapi/admin.yaml', 'openapi/store.yaml')
  end

  # A packaged installation has no docs/ directory beside the gem.
  it 'reads the copy packed into the gem when there is no source checkout' do
    stub_const("#{described_class}::SOURCE_DIR", '/nonexistent')

    expect(described_class.path('admin')).to eq(File.join(gem_root, 'openapi', 'admin.yaml'))
  end

  it 'prefers the source checkout, so a regenerated document is never shadowed by an old copy' do
    expect(described_class.path('admin')).to eq(File.expand_path('../../docs/api-reference/admin.yaml', gem_root))
  end

  it 'refuses to bundle when a document is missing' do
    stub_const("#{described_class}::SOURCE_DIR", '/nonexistent')

    expect { described_class.bundle! }.to raise_error(/admin.yaml is missing/)
  end
end
