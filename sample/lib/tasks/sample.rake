require 'ffaker'
require 'pathname'
require 'spree/sample'

namespace :spree_sample do
  desc 'Loads sample data'
  task :load => :environment do
    SpreeSample::Engine.load_samples
  end
end


