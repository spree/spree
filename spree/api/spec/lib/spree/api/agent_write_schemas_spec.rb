require 'spec_helper'

RSpec.describe Spree::Api::AgentWriteSchemas do
  # The published gems carry no docs/ directory; the release packs the
  # reference into the gem's openapi/ instead.
  it 'reads the reference packed into the gem when there is no source checkout' do
    Dir.mktmpdir do |dir|
      gem_root = Pathname(dir).join('gems', 'spree_api')
      allow(Spree::Api::Engine).to receive(:root).and_return(gem_root)

      expect(described_class.spec_path).to eq(gem_root.join('openapi', 'admin.yaml'))
    end
  end

  it 'prefers docs/ in a source checkout' do
    expect(described_class.spec_path.to_s).to end_with('docs/api-reference/admin.yaml')
  end
end
