class Spree::Base < ApplicationRecord
  include Spree::Preferences::Preferable
  serialize :preferences, Hash

  include Spree::RansackableAttributes

  after_initialize do
    if has_attribute?(:preferences) && !preferences.nil?
      self.preferences = default_preferences.merge(preferences)
    end
  end

  if Kaminari.config.page_method_name != :page
    def self.page(num)
      send Kaminari.config.page_method_name, num
    end
  end

  self.abstract_class = true

  def self.belongs_to_required_by_default
    false
  end

  def self.spree_base_scopes
    where(nil)
  end
end
