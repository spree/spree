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
  include Spree::ValidatesStoreUniqueness

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

  # The Seller API's counterpart, kept separate because sellers write a
  # narrower set than operators: an attribute an extension makes writable for
  # admins stays admin-only unless it is also declared here.
  #
  #   Spree::Product.additional_seller_permitted_attributes += [:brand_id]
  class_attribute :additional_seller_permitted_attributes, instance_writer: false, default: [].freeze

  # Backfills preferences added to the class after this row was last saved, so
  # a reader never sees nil for a newly defined preference. Only missing keys
  # are assigned: assigning unconditionally would dirty every record on load,
  # which is enough to make `with_lock` refuse the record ("unpersisted
  # changes").
  after_initialize do
    backfill_default_preferences if has_attribute?(:preferences) && !preferences.nil?
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
  # Resolves against the class's type registry where it has one, so an
  # unrecognized column value (an extension no longer installed) is never
  # constantized — it is shortened the same way instead, never sent as a class
  # name.
  #
  # @param type [String, nil] value of the STI `type` column
  # @return [String]
  def self.api_type_for(type)
    return api_type if type.blank?

    type = type.to_s
    api_type_registry.find { |klass| klass.to_s == type }&.api_type || type.demodulize.underscore
  end

  # Inverse of {.api_type_for}: the STI `type` column value for a wire
  # shorthand, or nil when no registered subclass answers to it. Lookup is
  # registry-driven, so a request can never name a class outside the family.
  #
  # @param api_type [String, nil] e.g. `"orders"`
  # @return [String, nil] e.g. `"Spree::Exports::Orders"`
  def self.class_name_for_api_type(api_type)
    return nil if api_type.blank?

    api_type_registry.find { |klass| klass.api_type == api_type.to_s }&.to_s
  end

  # The subclasses a typed family accepts — `registered_subclasses` for the
  # preference-schema families, `available_types` for exports and imports.
  #
  # @return [Array<Class>]
  def self.api_type_registry
    if subclass_registry
      registered_subclasses
    elsif respond_to?(:available_types)
      Array(available_types)
    else
      []
    end
  end

  # How a filter on one of this model's columns turns the short name a client
  # sends (`purchase_order`) into the class name the column stores, or nil
  # when the column does not store class names. Covers the STI column of a
  # typed family and polymorphic `*_type` columns; a model with another such
  # column overrides this.
  #
  # @param attribute [String]
  # @return [Proc, nil] short name → stored class name
  def self.api_type_resolver(attribute)
    if attribute == inheritance_column && api_type_registry.any?
      ->(api_type) { class_name_for_api_type(api_type) }
    elsif reflect_on_all_associations(:belongs_to).any? { |reflection| reflection.polymorphic? && reflection.foreign_type == attribute }
      ->(api_type) { Spree::Base.polymorphic_type_for(api_type) }
    end
  end

  # Shorthand for a *polymorphic* `*_type` column (`owner_type`,
  # `viewable_type`, …), where the value names an arbitrary model rather than a
  # subclass of the serialized one — so `api_type_for`'s registry lookup does
  # not apply. Demodulizes and underscores the same way `api_type` does, giving
  # `"Spree::Product"` => `"product"`.
  #
  # @param type [String, Class, nil] value of the polymorphic type column
  # @return [String, nil]
  #
  # The configured customer and admin user classes always answer `customer`
  # and `admin_user`, so a host app's own `User` class does not change the
  # contract.
  def self.polymorphic_api_type(type)
    return nil if type.blank?

    type = type.to_s
    return 'customer' if type == Spree.customer_class(constantize: false)
    return 'admin_user' if type == Spree.admin_user_class(constantize: false)

    type.demodulize.underscore
  end

  # Inverse of {.polymorphic_api_type}: the class name a polymorphic `*_type`
  # column stores for a wire shorthand. Matches against `candidates` when the
  # caller knows what the column may reference (always prefer that); otherwise
  # against the configured customer and admin user classes, then the
  # `Spree::` model of that name. Never constantizes the input.
  #
  # @param api_type [String, nil] e.g. `"purchase_order"`
  # @param candidates [Array<Class, String>, nil] classes the column may hold
  # @return [String, nil] e.g. `"Spree::PurchaseOrder"`
  def self.polymorphic_type_for(api_type, candidates = nil)
    token = api_type.to_s
    return nil unless token.match?(/\A[a-z][a-z0-9_]*\z/)

    candidates ||= [Spree.customer_class(constantize: false),
                    Spree.admin_user_class(constantize: false),
                    "Spree::#{token.camelize}"]
    candidates.map(&:to_s).find { |name| polymorphic_api_type(name) == token }
  end

  # Prefixed id for a polymorphic reference, encoded from the columns without
  # loading the row.
  #
  # Reads both halves together so a type never appears beside a null id: the
  # pair names something a client can link to, or neither does. Answers nil for
  # a model without `has_prefix_id` — an extension may point a polymorphic
  # column at one, and one such row must not 500 the whole list.
  #
  # @param type [String, nil] the polymorphic `*_type` column
  # @param id [Integer, String, nil] the polymorphic `*_id` column
  # @return [String, nil]
  def self.polymorphic_prefixed_id(type, id)
    return nil if type.blank? || id.blank?

    type.to_s.safe_constantize.try(:prefixed_id_for, id)
  end

  # Reads the arguments of a two-state ransackable scope — one that answers a
  # question with two named sides ("erased" / "not erased", "outstanding" /
  # "spent") rather than narrowing to a value.
  #
  # Declare such a scope as `->(*values)`, never `->(value = true)`. Ransack
  # calls one of three ways, and only a splat survives all of them:
  #
  # - a literal boolean `true` invokes the scope with NO arguments, which
  #   means the affirmative side (this is why an empty list reads as `true`);
  # - a single value arrives as that value;
  # - an array predicate is SPLATTED, so a filter offering both sides passes
  #   two arguments and a fixed-arity lambda raises ArgumentError — a 500 on a
  #   request the merchant is entitled to make. Asking for every side is no
  #   constraint at all, which is the `nil` below.
  #
  # The scope must also be listed in the model's
  # `ransackable_scopes_skip_sanitize_args`, or Ransack casts `false` itself
  # and then declines to apply the scope at all.
  #
  # @param values [Array<Object>] whatever Ransack passed through
  # @return [Boolean, nil] the side asked for, or nil when every side was
  def self.ransack_flag(*values)
    # No argument is Ransack's shorthand for the affirmative side, not an
    # absent filter: `q[erased]=true` reaches the scope with nothing at all.
    return true if values.empty?

    flags = Array(values).flatten.map { |value| ActiveModel::Type::Boolean.new.cast(value) }.uniq
    # `size == 1`, not `one?`: the latter counts truthy elements, so a lone
    # `false` would read as "no side chosen" and drop the filter.
    return nil unless flags.size == 1

    flags.first
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
