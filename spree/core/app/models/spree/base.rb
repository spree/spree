class Spree::Base < ApplicationRecord
  include Spree::Preferences::Preferable
  include Spree::RansackableAttributes
  include Spree::TranslatableResourceScopes
  include Spree::IntegrationsConcern
  include Spree::Publishable
  include Spree::PrefixedId

  after_initialize do
    if has_attribute?(:preferences) && !preferences.nil?
      self.preferences = default_preferences.merge(preferences)
    end
  end

  # only for backwards compatibility with Kaminari
  if defined?(Kaminari) && Kaminari.config.page_method_name != :page
    def self.page(num)
      send Kaminari.config.page_method_name, num
    end
  end

  self.abstract_class = true

  scope :for_ordering_with_translations, lambda { |klass, fields = nil|
    select("#{klass.table_name}.*").select(*(fields || klass::TRANSLATABLE_FIELDS))
  }

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

  # this can overridden in subclasses to disallow deletion
  def can_be_deleted?
    true
  end

  def self.json_api_columns
    column_names.reject { |c| c.match(/_id$|id|preferences|(.*)password|(.*)token|(.*)api_key|^original_(.*)/) }
  end

  def self.json_api_permitted_attributes
    skipped_attributes = %w[id]

    if included_modules.include?(CollectiveIdea::Acts::NestedSet::Model)
      skipped_attributes.push('lft', 'rgt', 'depth')
    end

    column_names.reject { |c| skipped_attributes.include?(c.to_s) }
  end

  # Public-API shorthand for this class, used as the `type` value on the
  # wire (e.g. `"currency"` for `Spree::Promotion::Rules::Currency`,
  # `"flat_rate"` for `Spree::Calculator::FlatRate`). Defaults to the
  # demodulized + underscored leaf; override on a subclass when the wire
  # format should stay stable across class renames.
  def self.api_type
    to_s.demodulize.underscore
  end

  # Backwards-compatible alias for `.api_type`. Delegates so subclass
  # overrides of `api_type` are honored.
  def self.json_api_type
    api_type
  end

  def self.to_tom_select_json
    pluck(:name, :id).map do |name, id|
      {
        id: id,
        name: name
      }
    end.as_json
  end

  def uuid_for_friendly_id
    SecureRandom.uuid
  end

  # Try building a slug based on the following fields in increasing order of specificity.
  def slug_candidates
    if defined?(deleted_at) && deleted_at.present?
      [
        ['deleted', :name],
        ['deleted', :name, :uuid_for_friendly_id]
      ]
    else
      [
        [:name],
        [:name, :uuid_for_friendly_id]
      ]
    end
  end
end
