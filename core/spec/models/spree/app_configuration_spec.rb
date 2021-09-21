require 'spec_helper'

describe Spree::AppConfiguration, type: :model do
  let (:prefs) { Rails.application.config.spree.preferences }

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
