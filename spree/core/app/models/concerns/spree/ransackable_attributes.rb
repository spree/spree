module Spree::RansackableAttributes
  extend ActiveSupport::Concern

  # Ransack `auth_object` values for callers outside the back office. The
  # allowlists below were written for staff; a shopper or a seller filtering
  # on them would get a yes/no answer about data their responses never show.
  RESTRICTED_AUDIENCES = %i[store seller].freeze

  included do
    class_attribute :whitelisted_ransackable_associations
    class_attribute :whitelisted_ransackable_attributes
    class_attribute :whitelisted_ransackable_scopes

    # `{ 'price_between' => %w[decimal decimal], 'in_categories' => { list: 'id' } }`
    # — the arguments a ransackable scope takes, which Ruby cannot report for
    # a `scope` lambda. A scope taking none is `'boolean'`; an undeclared one
    # is published as taking one text value.
    class_attribute :ransackable_scope_types, default: {}

    # Associations the Store API may filter through. Empty by default: every
    # hop is a join into data the storefront was never meant to query, and a
    # join back to the model it came from lets one filter chain them forever.
    class_attribute :storefront_ransackable_associations, default: []

    # `{ store: [...], seller: [...] }` — attributes and scopes a restricted
    # audience may not filter on, although staff may.
    class_attribute :private_ransackable_attributes, default: {}
    class_attribute :private_ransackable_scopes, default: {}

    # Attributes the `search` filter matches, set with {.search_by}.
    class_attribute :search_attributes, default: [], instance_accessor: false

    class_attribute :default_ransackable_attributes
    # `position` is included so any `acts_as_list` model is sortable by it
    # without each subclass having to opt in. Ransack ignores attributes
    # the model doesn't actually expose, so this is a no-op for tables
    # without a position column.
    self.default_ransackable_attributes = %w[id name updated_at created_at position]

    def self.ransackable_associations(auth_object = nil)
      if Spree::RansackableAttributes.restricted_audience?(auth_object)
        return auth_object.to_sym == :store ? storefront_ransackable_associations : []
      end

      base = whitelisted_ransackable_associations || []
      base | Spree.ransack.custom_associations_for(self)
    end

    def self.ransackable_attributes(auth_object = nil)
      base = default_ransackable_attributes | (whitelisted_ransackable_attributes || [])
      base |= Spree.ransack.custom_attributes_for(self)
      return base unless Spree::RansackableAttributes.restricted_audience?(auth_object)

      base - Array(private_ransackable_attributes[auth_object.to_sym])
    end

    def self.ransackable_scopes(auth_object = nil)
      base = (whitelisted_ransackable_scopes || []).map(&:to_s)
      base |= Spree.ransack.custom_scopes_for(self).map(&:to_s)
      base |= %w[search] if search_attributes.any? && search_attributes.all? { |path| ransackable_path?(path, auth_object) }
      return base unless Spree::RansackableAttributes.restricted_audience?(auth_object)

      base - Array(private_ransackable_scopes[auth_object.to_sym])
    end

    # Declares the `search` filter (`q[search]=term`): a case-insensitive
    # partial match on any of the given attributes, which may reach through
    # associations (`variant_sku`). It runs as Ransack's `_cont` on those
    # attributes, so translated names match in the current locale. An
    # audience that may not filter on every one of them does not get it.
    #
    #   search_by :name, :code
    #
    # @param attributes [Array<Symbol, String>]
    def self.search_by(*attributes)
      self.search_attributes = attributes.map(&:to_s).freeze
      scope :search, ->(query) {
        query.blank? ? all : ransack("#{search_attributes.join('_or_')}_cont" => query.to_s.strip).result
      }
    end

    # Whether an attribute, or one reached through associations
    # (`variant_product_name`), is filterable by this audience.
    #
    # @param path [String]
    # @param auth_object [Symbol, nil]
    # @return [Boolean]
    def self.ransackable_path?(path, auth_object = nil, depth = 0)
      return true if ransackable_attributes(auth_object).include?(path)
      return false if depth >= 2

      ransackable_associations(auth_object).any? do |name|
        next false unless path.start_with?("#{name}_")

        reflection = reflect_on_association(name.to_sym)
        next false if reflection.nil? || reflection.polymorphic? || !reflection.klass.respond_to?(:ransackable_path?)

        reflection.klass.ransackable_path?(path.delete_prefix("#{name}_"), auth_object, depth + 1)
      end
    end
  end

  # @param auth_object [Symbol, nil] the Ransack auth object a search ran with
  # @return [Boolean] whether it names a caller outside the back office
  def self.restricted_audience?(auth_object)
    auth_object.respond_to?(:to_sym) && RESTRICTED_AUDIENCES.include?(auth_object.to_sym)
  end
end
