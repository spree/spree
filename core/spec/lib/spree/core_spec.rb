require 'spec_helper'

describe Spree do
  describe '.admin_path' do
    it { expect(Spree.admin_path).to eq(Spree::Config[:admin_path]) }
  end

  describe '.admin_path=' do
    let!(:original_admin_path) { Spree.admin_path }
    let(:new_admin_path) { '/admin-secret-path' }

    before do
      Spree.admin_path = new_admin_path
    end

    it { expect(Spree.admin_path).to eq(new_admin_path) }
    it { expect(Spree::Config[:admin_path]).to eq(new_admin_path) }

    after do
      Spree.admin_path = original_admin_path
    end
  end
end
