class Spree::Base < ActiveRecord::Base
  include Spree::Preferences::Preferable
  self.abstract_class = true
end