module Spree
  # Declares a "who performed this action" association — the canceler of an
  # order, the receiver of a stock delivery, the opener of a return.
  #
  #   class Spree::Order < Spree.base_class
  #     include Spree::ActedBy
  #     acted_by :created_by, :approver, :canceler
  #   end
  #
  # Each name becomes an optional polymorphic `belongs_to` whose type column is
  # validated against `Spree.actor_classes`, so a row can only ever name a
  # registered actor — an admin user, an API key, or a class an extension
  # registered. See docs/plans/6.0-action-actors.md.
  #
  # Association names, readers and writers are the ones a plain `belongs_to`
  # would give, so the workflows that assign these (`order.canceler = canceler`)
  # are untouched by the conversion.
  module ActedBy
    extend ActiveSupport::Concern

    # Every model that declares at least one `acted_by` association, so a
    # caller sweeping actor columns — the backfill task, a user's erasure —
    # walks all of them without being handed a list.
    #
    # The registry fills as models load, so it eager-loads first: in
    # development nothing is loaded until something references it, and a
    # caller that silently skipped an unloaded model would leave a deleted
    # person's id behind or half-finish an upgrade.
    #
    # Names are held rather than classes, and resolved on read, so a code
    # reload does not leave the registry pointing at superseded copies of the
    # same model.
    #
    # @return [Array<Class>]
    def self.models
      Rails.application&.eager_load! unless Rails.application&.config&.eager_load

      registered_model_names.filter_map(&:safe_constantize)
    end

    # @api private
    # @return [Set<String>]
    def self.registered_model_names
      @registered_model_names ||= Set.new
    end

    included do
      # The names declared on this class, so the backfill task can ask a model
      # what it records without being told. Inherited and extended per class,
      # never assigned, so a subclass adding one does not blank its parent's.
      class_attribute :acted_by_associations, default: [], instance_writer: false
    end

    # The class an actor column names, answering what the reader would resolve
    # rather than what the column literally holds: a row the backfill has not
    # reached carries an id and no type, and the reader resolves it through
    # the admin user class. Serializers read this so `<name>_id` and
    # `<name>_type` never disagree about the same row.
    #
    # @param name [Symbol, String] the acted_by association
    # @return [String, nil]
    def acted_by_type(name)
      stored = self[:"#{name}_type"]
      return stored if stored.present?

      Spree.admin_user_class.to_s if self[:"#{name}_id"].present?
    end

    # The actor's prefixed id, encoded from the columns without loading the
    # row — so a page of orders costs no query per actor it names. Paired with
    # {#acted_by_type} so the id and the kind always describe the same row,
    # including one the backfill has not reached.
    #
    # @param name [Symbol, String] the acted_by association
    # @return [String, nil]
    def acted_by_prefixed_id(name)
      Spree::Base.polymorphic_prefixed_id(acted_by_type(name), self[:"#{name}_id"])
    end

    # Names the admin user class on every un-backfilled row of `record`'s
    # lazily-preloaded group, so the association preloads as one query rather
    # than one per row. Writes the in-memory attribute only; nothing is saved.
    #
    # @api private
    # @param record [ActiveRecord::Base]
    # @param name [Symbol] the acted_by association
    # @return [void]
    def self.assume_admin_actor_type(record, name)
      type_column = :"#{name}_type"
      admin_type = Spree.admin_user_class.to_s
      group = record.try(:lazy_preload_context)&.records.presence || [record]

      group.each do |sibling|
        next unless sibling.instance_of?(record.class)
        next if sibling[type_column].present? || sibling[:"#{name}_id"].blank?

        sibling[type_column] = admin_type
      end
    end

    # Both halves of an actor column, for a caller writing through
    # `update_columns` or `update_all` rather than through the association —
    # an id without its type names nothing, so the pair is produced together
    # and never by hand.
    #
    #   changes.merge!(Spree::ActedBy.columns_for(:canceler, canceler))
    #
    # The actor is checked against the registry here because these writes go
    # through `update_columns` / `update_all`, which skip validation — without
    # it an unregistered actor persists as a row the model itself calls
    # invalid.
    #
    # @param name [Symbol, String] the acted_by association
    # @param actor [Object, nil]
    # @raise [ArgumentError] when the actor's class is not registered
    # @return [Hash{Symbol => Object, nil}]
    def self.columns_for(name, actor)
      type = actor && actor.class.polymorphic_name

      if type.present? && Spree.actor_classes.exclude?(type)
        raise ArgumentError, "#{type} is not a registered actor class — add it to Spree.actor_classes"
      end

      { :"#{name}_id" => actor&.id, :"#{name}_type" => type }
    end

    class_methods do
      # @param names [Array<Symbol>] the association names to declare
      # @return [void]
      def acted_by(*names)
        names = names.map(&:to_sym)
        self.acted_by_associations = acted_by_associations + names
        # An anonymous class — one built in a spec or a console — has no name
        # to register, and a nil in the registry would break every later read.
        Spree::ActedBy.registered_model_names << name_for_actor_registry if name_for_actor_registry

        names.each do |name|
          belongs_to name, polymorphic: true, optional: true

          validate_actor_type(name)
          define_transitional_actor_reader(name)
        end
      end

      private

      # STI subclasses register under the base class, whose table the backfill
      # updates; an anonymous class registers nothing.
      def name_for_actor_registry
        base_class.name
      end

      def validate_actor_type(name)
        type_column = :"#{name}_type"

        validate do
          value = self[type_column]
          next if value.blank? || Spree.actor_classes.include?(value)

          errors.add(type_column, :unregistered_actor,
                     message: Spree.t('errors.messages.unregistered_actor'))
        end
      end

      # Rows written before the type column existed carry an id and no type,
      # which a polymorphic association reads as nil. Until the backfill task
      # has run they resolve through the admin user class, the only thing they
      # could ever have pointed at.
      #
      # The type is filled in on the in-memory attribute and the ordinary
      # association reader does the rest, so the fallback keeps every benefit
      # the association has — preloading included. Resolving it with a direct
      # `find_by` instead would sidestep `ar_lazy_preload`, turning a page of
      # 25 orders into 75 queries while the backfill is outstanding.
      #
      # Nothing is saved: `[]=` writes the attribute, and a record whose only
      # change is this would still need an explicit save to persist it.
      # Prepended rather than defined outright, so `super` reaches the
      # generated reader.
      #
      # Removed in 6.1, once the backfill is a release behind.
      def define_transitional_actor_reader(name)
        transitional_actor_readers.module_eval do
          define_method(name) do
            return super() if self[:"#{name}_type"].present?
            return super() if self[:"#{name}_id"].blank?

            Spree::Deprecation.warn(
              "#{self.class.name}##{name} resolved through #{Spree.admin_user_class} because " \
              "#{name}_type is blank. Run `rake spree:upgrade:backfill_actor_types`; the fallback " \
              'is removed in Spree 6.1.'
            )

            # Fill the type across the whole lazily-preloaded group, not just
            # this record: the preloader batches on the type it finds, and
            # filling one row at a time as each is read produces a query per
            # row instead of one for the page.
            Spree::ActedBy.assume_admin_actor_type(self, name)
            super()
          end
        end
      end

      # The per-class module the transitional readers live in, prepended once.
      def transitional_actor_readers
        @transitional_actor_readers ||= Module.new.tap { |mod| prepend(mod) }
      end
    end
  end
end
