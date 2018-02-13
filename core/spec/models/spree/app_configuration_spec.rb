require 'spec_helper'

describe Spree::AppConfiguration, type: :model do
  let (:prefs) { Rails.application.config.spree.preferences }

  it 'is available from the environment' do
    prefs.layout = 'my/layout'
    expect(prefs.layout).to eq 'my/layout'
  end

  it 'is available as Spree::Config for legacy access' do
    Spree::Config.layout = 'my/layout'
    expect(Spree::Config.layout).to eq 'my/layout'
  end

  it 'uses base searcher class by default' do
    prefs.searcher_class = nil
    expect(prefs.searcher_class).to eq Spree::Core::Search::Base
  end

  describe 'admin_path' do
    it { expect(Spree::Config).to have_preference(:admin_path) }
    it { expect(Spree::Config.preferred_admin_path_type).to eq(:string) }
    it { expect(Spree::Config.preferred_admin_path_default).to eq('/admin') }
  end
end
