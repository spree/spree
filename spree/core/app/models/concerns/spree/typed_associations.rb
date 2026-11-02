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

      # Cleared only once the rows are written: a refused row rolls the save
      # back, and a retried save must carry the rows again rather than
      # persist the owner without them.
      reconcile_typed_association(association, pending)
      instance_variable_set(ivar, nil)
    end

    # All or nothing: on a saved parent the rows are written as they are
    # assigned, so a refusal on the second row used to leave the first one
    # behind — a list the caller never asked for, answered with a 422.
    def reconcile_typed_association(association, rows)
      collection = public_send(association)
      begin
        self.class.transaction do
          kept_ids = rows.each_with_index.map { |row, index| save_typed_association_row(collection, row, "/#{association.to_s.split('_').last}/#{index}") }
          collection.where.not(id: kept_ids).destroy_all
          # `where.not(...).destroy_all` deletes the dropped rows from the DB but
          # leaves them in the already-loaded association target. Reset so a
          # same-request read (e.g. the serializer rendering `rule_ids`) reflects
          # the removal instead of echoing ghosts.
          collection.reset
        end
      rescue StandardError
        # The rows built before the refusal are still in the loaded target, and
        # the owner's next save would write them; the rollback only undid the
        # database.
        collection.reset
        raise
      end
    end

    # @param pointer [String] where the row sits in the request, e.g. `/rules/1`
    def save_typed_association_row(collection, row, pointer)
      record = find_or_build_typed_association_row(collection, row, pointer)

      preferences = row[:preferences]
      calculator = row[:calculator]
      attrs = row.except(:id, :type, :preferences, :calculator)

      # `*_ids` mass-assignment on a new record builds join rows with a
      # nil parent FK and fails `presence: true` on autosave. Defer
      # those until after the row itself is persisted.
      deferred_ids, scalar_attrs = attrs.partition { |k, _| record.new_record? && k.to_s.end_with?('_ids') }
      record.assign_attributes(scalar_attrs.to_h) if scalar_attrs.any?

      record.assign_preferences(preferences, pointer: "#{pointer}/preferences") if preferences
      if calculator.present? && record.respond_to?(:assign_calculator_attributes)
        record.assign_calculator_attributes(calculator, pointer: "#{pointer}/calculator")
      end

      # Always save — `record.changed?` doesn't reflect preferences
      # (serialized hash) or calculator association changes.
      record.save!

      deferred_ids.each { |key, value| record.public_send("#{key}=", value) }
      record.save! if record.changed?

      record.id
    rescue ActiveRecord::RecordInvalid => e
      # A row saved from the owner's `after_save` fails inside the owner's own
      # save, and a plain `save` swallows the exception — so its errors are
      # copied onto the owner, or the caller learns only that something failed.
      e.record.errors.full_messages.each { |message| errors.add(:base, message) }
      raise
    end

    def find_or_build_typed_association_row(collection, row, pointer)
      if row[:id].present?
        id = Spree::PrefixedId.prefixed_id?(row[:id]) ? Spree::PrefixedId.decode_prefixed_id(row[:id]) : row[:id]
        existing = collection.find { |r| r.id == id } || collection.find_by(id: id)
        return existing if existing
      end

      family = collection.proxy_association.klass
      klass = family.find_by_api_type(row[:type])
      # Refused, not skipped: a dropped row answered the request with a 200
      # and a promotion that discounted nothing. Naming the accepted types is
      # what lets an API client or an agent correct itself.
      raise unknown_row_type_error(family, row[:type], pointer) unless klass

      # `build(type:) + becomes(klass)` would leave a stale STI-parent stub
      # in the collection target alongside the becomes'd copy; autosave then
      # validates both under different identities and uniqueness checks fail.
      record = klass.new
      collection.proxy_association.add_to_target(record)
      record
    end

    def unknown_row_type_error(family, type, pointer)
      types = family.api_types.sort.join(', ')
      message = if type.blank?
                  I18n.t('spree.errors.messages.missing_row_type', types: types)
                else
                  I18n.t('spree.errors.messages.unknown_row_type', type: type, family: family.model_name.human.downcase, types: types)
                end

      Spree::Preferences::InvalidPreferences.new([{ pointer: '/type', message: message }], prefix: pointer)
    end
  end
end
