module Spree
  # Shared flat-payload writer for `has_many` associations whose rows
  # are STI-typed and carry preferences/calculator metadata. Used by
  # {Spree::Promotion} (rules, actions) and {Spree::PriceList} (rules).
  #
  # The wire shape is `[{ type:, id?, preferences: {...}, calculator?: {...}, *_ids?: [...] }]`
  # and the reconciliation is: existing rows update by `id`, new rows
  # build via `find_by_api_type`, missing rows destroy. Falls through
  # to AR's standard writer when assigned model instances (Rails
  # internals do this on association swap).
  #
  # New-record parents defer the work into an `@pending_<assoc>` ivar
  # so child rows can FK to a persisted parent — the consumer model
  # is responsible for flushing those in an `after_save`.
  module TypedAssociations
    extend ActiveSupport::Concern

    private

    # Routes a flat-payload assignment to either the deferred buffer
    # (new record) or {#reconcile_typed_association}.
    #
    # @param association [Symbol] e.g. `:promotion_rules`, `:price_rules`
    # @param rows [Array<Hash>, Array<Spree::Base>, nil]
    # @return [void]
    def assign_typed_association(association, rows)
      first = Array(rows).first
      return public_send(:"#{association}=", rows) if first.nil? || first.is_a?(Spree.base_class)

      pending = Array(rows).map { |entry| entry.respond_to?(:to_h) ? entry.to_h.with_indifferent_access : entry.with_indifferent_access }

      if new_record?
        instance_variable_set(:"@pending_#{association}", pending)
        return
      end

      reconcile_typed_association(association, pending)
    end

    # Flushes a pending payload from `@pending_<assoc>` (typically from
    # an `after_save` hook) and clears the ivar.
    #
    # @param association [Symbol]
    # @return [void]
    def flush_pending_typed_association(association)
      ivar = :"@pending_#{association}"
      pending = instance_variable_get(ivar)
      return unless pending

      instance_variable_set(ivar, nil)
      reconcile_typed_association(association, pending)
    end

    def reconcile_typed_association(association, rows)
      collection = public_send(association)
      kept_ids = rows.filter_map { |row| save_typed_association_row(collection, row) }
      collection.where.not(id: kept_ids).destroy_all if kept_ids.any? || rows.empty?
    end

    def save_typed_association_row(collection, row)
      record = find_or_build_typed_association_row(collection, row)
      return nil unless record

      preferences = row[:preferences]
      calculator = row[:calculator]
      attrs = row.except(:id, :type, :preferences, :calculator)

      # `*_ids` mass-assignment on a new record builds join rows with a
      # nil parent FK and fails `presence: true` on autosave. Defer
      # those until after the row itself is persisted.
      deferred_ids, scalar_attrs = attrs.partition { |k, _| record.new_record? && k.to_s.end_with?('_ids') }
      record.assign_attributes(scalar_attrs.to_h) if scalar_attrs.any?

      preferences&.each do |key, value|
        next unless record.has_preference?(key.to_sym)

        record.set_preference(key.to_sym, decode_preference_value(key, value))
      end
      record.assign_calculator_attributes(calculator) if calculator.present? && record.respond_to?(:assign_calculator_attributes)

      # Always save — `record.changed?` doesn't reflect preferences
      # (serialized hash) or calculator association changes.
      record.save!

      deferred_ids.each { |key, value| record.public_send("#{key}=", value) }
      record.save! if record.changed?

      record.id
    end

    # Decode `*_ids` array preferences (`customer_group_ids`, `user_ids`,
    # …) from prefixed strings to raw PKs. Plain-scalar / non-id
    # preferences pass through unchanged.
    def decode_preference_value(key, value)
      return value unless key.to_s.end_with?('_ids') && value.is_a?(Array)

      value.map do |v|
        Spree::PrefixedId.prefixed_id?(v) ? Spree::PrefixedId.decode_prefixed_id(v) : v
      end
    end

    def find_or_build_typed_association_row(collection, row)
      if row[:id].present?
        id = Spree::PrefixedId.prefixed_id?(row[:id]) ? Spree::PrefixedId.decode_prefixed_id(row[:id]) : row[:id]
        existing = collection.find { |r| r.id == id } || collection.find_by(id: id)
        return existing if existing
      end

      klass = collection.proxy_association.klass.find_by_api_type(row[:type])
      return nil unless klass

      record = collection.build(type: klass.to_s)
      record.class == klass ? record : record.becomes(klass)
    end
  end
end
