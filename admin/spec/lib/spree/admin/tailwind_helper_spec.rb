require 'spec_helper'
require 'spree/admin/tailwind_helper'

RSpec.describe Spree::Admin::TailwindHelper do
  describe '.input_path' do
    it 'returns the host app spree_admin.css path' do
      expect(described_class.input_path).to eq(Rails.root.join("app/assets/tailwind/spree_admin.css"))
    end
  end

  describe '.output_path' do
    it 'returns the builds output path' do
      expect(described_class.output_path).to eq(Rails.root.join("app/assets/builds/spree/admin/application.css"))
    end
  end

  describe '.resolved_input_path' do
    it 'returns the temp file path for resolved CSS' do
      expect(described_class.resolved_input_path).to eq(Rails.root.join("tmp/tailwind/spree_admin_resolved.css"))
    end
  end

  describe '.engine_css_path' do
    it 'returns the engine tailwind assets path' do
      expect(described_class.engine_css_path).to eq(Spree::Admin::Engine.root.join("app/assets/tailwind"))
    end
  end

  describe '.resolved_input_css' do
    it 'replaces $SPREE_ADMIN_PATH with engine root' do
      result = described_class.resolved_input_css

      expect(result).to include(Spree::Admin::Engine.root.to_s)
      expect(result).not_to include('$SPREE_ADMIN_PATH')
    end
  end

  describe '.write_resolved_css' do
    after do
      FileUtils.rm_rf(Rails.root.join("tmp/tailwind"))
    end

    it 'creates the resolved CSS file' do
      path = described_class.write_resolved_css

      expect(File.exist?(path)).to be true
    end

    it 'returns the resolved input path' do
      path = described_class.write_resolved_css

      expect(path).to eq(described_class.resolved_input_path)
    end

    it 'writes CSS without $SPREE_ADMIN_PATH variable' do
      path = described_class.write_resolved_css
      content = File.read(path)

      expect(content).not_to include('$SPREE_ADMIN_PATH')
      expect(content).to include(Spree::Admin::Engine.root.to_s)
    end

    it 'creates the directory if it does not exist' do
      FileUtils.rm_rf(Rails.root.join("tmp/tailwind"))

      described_class.write_resolved_css

      expect(File.directory?(Rails.root.join("tmp/tailwind"))).to be true
    end
  end
end
