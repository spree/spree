class Spree::Base < ApplicationRecord
  include Spree::Preferences::Preferable
  include Spree::PreferenceSchema
  include Spree::RansackableAttributes
  include Spree::TranslatableResourceScopes
  include Spree::IntegrationsConcern
  include Spree::Publishable
  include Spree::PrefixedId
  include Spree::HasNumber
  include Spree::HasIsoGeography
  include Spree::TypedAssociations

  # Extra writable attributes contributed by extensions, appended to the v3
  # controller allowlist for this resource. Core attributes belong in the
  # controller's own list — this exists so an extension that adds a column can
  # make it writable without decorating a controller:
  #
  #   Spree::Product.additional_permitted_attributes += [:brand_id]
  #
  # Entries are `params.permit` fragments: bare symbols, or hashes for
  # collections and nested structures (`{ region_ids: [] }`). Append with `+=`
  # rather than assigning, so extensions don't clobber each other.
  class_attribute :additional_permitted_attributes, instance_writer: false, default: [].freeze

  # Backfills preferences added to the class after this row was last saved, so
  # a reader never sees nil for a newly defined preference. Assigning
  # unconditionally would dirty every record on load: `preferences` is a
  # YAML-serialized Hash, so the dirty check compares the serialized string and
  # the merge reorders keys even when nothing changed — which is enough to make
  # `with_lock` refuse the record ("unpersisted changes").
  after_initialize do
    if has_attribute?(:preferences) && !preferences.nil?
      missing = default_preferences.except(*preferences.keys)
      self.preferences = preferences.merge(missing) if missing.any?
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

  # this can overridden in subclasses to disallow deletion
  def can_be_deleted?
    true
  end

  # @see Spree.mysql? — the single definition; this reads it so a model can
  #   branch without reaching for the connection itself.
  def mysql_adapter?
    Spree.mysql?
  end

  def self.json_api_columns
    # `_type` goes with `_id`: the two halves of a polymorphic reference name
    # an internal class, which is no more public than the key beside it.
    column_names.reject { |c| c.match(/_id$|id|_type$|preferences|(.*)password|(.*)token|(.*)api_key|^original_(.*)/) }
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

  # `.api_type` for an STI `type` column value, without instantiating the
  # subclass — use this in serializers instead of `record.class.api_type`,
  # which reports the *loaded* class and so returns the base type for a record
  # read through the parent (a plain `Spree::Export` row, a factory that sets
  # `type` as an attribute, a query on the base relation).
  #
  # Resolves against `available_types` where the class defines it, so an
  # unrecognized column value passes through untouched rather than being
  # constantized.
  #
  # @param type [String, nil] value of the STI `type` column
  # @return [String]
  def self.api_type_for(type)
    return api_type if type.blank?

    type = type.to_s
    return type unless respond_to?(:available_types)

    available_types.find { |klass| klass.to_s == type }&.api_type || type
  end

  # Shorthand for a *polymorphic* `*_type` column (`owner_type`,
  # `viewable_type`, …), where the value names an arbitrary model rather than a
  # subclass of the serialized one — so `api_type_for`'s registry lookup does
  # not apply. Demodulizes and underscores the same way `api_type` does, giving
  # `"Spree::Product"` => `"product"`.
  #
  # @param type [String, Class, nil] value of the polymorphic type column
  # @return [String, nil]
  def self.polymorphic_api_type(type)
    return nil if type.blank?

    type.to_s.demodulize.underscore
  end

  # @deprecated Legacy Tom Select helper for the removed Rails admin. No replacement.
  def self.to_tom_select_json
    Spree::Deprecation.warn('Spree::Base.to_tom_select_json is deprecated and will be removed in Spree 6.1.')

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
