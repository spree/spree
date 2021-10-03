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

  def self.for_store(store)
    plural_model_name = model_name.plural.gsub(/spree_/, '').to_sym

    if store.respond_to?(plural_model_name)
      store.send(plural_model_name)
    else
      self
    end
  end

  def self.spree_base_scopes
    where(nil)
  end

  def self.spree_base_uniqueness_scope
    ApplicationRecord.try(:spree_base_uniqueness_scope) || []
  end

  # FIXME: https://github.com/rails/rails/issues/40943
  def self.has_many_inversing
    false
  end

  def self.json_api_columns
    column_names.reject { |c| c.match(/_id$|id|preferences|(.*)password|(.*)token|(.*)api_key/) }
  end

  def self.json_api_permitted_attributes
    skipped_attributes = %w[id]

    if included_modules.include?(CollectiveIdea::Acts::NestedSet::Model)
      skipped_attributes.push('lft', 'rgt', 'depth')
    end

    column_names.reject { |c| skipped_attributes.include?(c.to_s) }
  end

  def self.json_api_type
    to_s.demodulize.underscore
  end
end
