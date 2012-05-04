Spree::Zone.class_eval do
  def self.global
    find_by_name("GlobalZone") || create(:global_zone)
  end
end

require 'factory_girl'
# include FactoryGirl::Syntax::Methods # TODO: This can be removed when using FactoryGirl 3.2.x

Dir["#{File.dirname(__FILE__)}/factories/**"].each do |f|
  require File.expand_path(f)
end
