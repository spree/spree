require 'spec_helper'

describe Spree::Core::Configuration, type: :model do
  let (:prefs) { Rails.application.config.spree.preferences }

  it 'uses base searcher class by default' do
    prefs.searcher_class = nil
    expect(prefs.searcher_class).to eq Spree::Core::Search::Base
  end
end
