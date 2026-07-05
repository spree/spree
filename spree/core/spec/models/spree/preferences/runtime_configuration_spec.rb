require 'spec_helper'

describe Spree::Preferences::RuntimeConfiguration, type: :model do
  let(:test_class) do
    Class.new(Spree::Preferences::RuntimeConfiguration) do
      preference :admin_path, :string, default: '/admin'
      preference :page_size, :integer
    end
  end

  subject { test_class.new }

  describe '#get' do
    it 'returns default value if present' do
      expect(subject.get(:admin_path)).to eq('/admin')
    end

    it 'returns nil if not present' do
      expect(subject.get(:page_size)).to be_nil
    end

    it 'returns value via an attribute accessor' do
      expect(subject.admin_path).to eq('/admin')
    end

    it 'returns value via a hash accessor' do
      expect(subject[:admin_path]).to eq('/admin')
    end
  end

  describe '#set' do
    it 'overrides the default value' do
      subject.set(:admin_path, '/secret_admin')
      expect(subject.get(:admin_path)).to eq('/secret_admin')
    end

    it 'sets value if not set previously' do
      subject.set(:page_size, 10)
      expect(subject.get(:page_size)).to eq(10)
    end

    it 'sets the value via an attribute accessor' do
      subject.page_size = 10
      expect(subject.get(:page_size)).to eq(10)
    end

    it 'sets value via a hash accessor' do
      subject[:page_size] = 10
      expect(subject.get(:page_size)).to eq(10)
    end
  end
end
