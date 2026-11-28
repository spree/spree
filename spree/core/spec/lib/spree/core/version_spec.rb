# frozen_string_literal: true

require 'spec_helper'

# The npm version converter in scripts/version-packages.mjs only reads the
# RubyGems spelling (6.1.0.dev, 6.0.0.rc7), and RubyGems rewrites any other
# spelling, so the built gem would not match Spree.version.
RSpec.describe 'Spree::VERSION' do
  it 'is spelled the way RubyGems writes it' do
    expect(Gem::Version.new(Spree::VERSION).to_s).to eq(Spree::VERSION)
    expect(Spree::VERSION).to match(/\A\d+\.\d+\.\d+(\.[a-z]+\d*)?\z/)
  end
end
