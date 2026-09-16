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

    # Every model that declares at least one `acted_by` association, so the
    # backfill task can walk them without being handed a list. Populated at
    # class load; eager loading is what makes it complete, which is why the
    # task runs against a booted application.
    #
    # Names are held rather than classes, and resolved on read, so a code
    # reload in development does not leave the registry pointing at
    # superseded copies of the same model.
    #
    # @return [Array<Class>]
    def self.models
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

    # Drops the transitional lookups the readers memoized — a reload may have
    # brought the backfilled type with it.
    def reload(*)
      @transitional_actors = nil
      super
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

    # Both halves of an actor column, for a caller writing through
    # `update_columns` or `update_all` rather than through the association —
    # an id without its type names nothing, so the pair is produced together
    # and never by hand.
    #
    #   changes.merge!(Spree::ActedBy.columns_for(:canceler, canceler))
    #
    # @param name [Symbol, String] the acted_by association
    # @param actor [Object, nil]
    # @return [Hash{Symbol => Object, nil}]
    def self.columns_for(name, actor)
      {
        :"#{name}_id" => actor&.id,
        :"#{name}_type" => actor && actor.class.polymorphic_name
      }
    end

    class_methods do
      # @param names [Array<Symbol>] the association names to declare
      # @return [void]
      def acted_by(*names)
        names = names.map(&:to_sym)
        self.acted_by_associations = acted_by_associations + names
        Spree::ActedBy.registered_model_names << name_for_actor_registry

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
      # Prepended rather than defined outright, so `super` still reaches the
      # generated association reader for every row that does carry a type.
      #
      # The lookup is memoized per record and the warning raised once per
      # record: a serialized page of orders touches three actors per row, and
      # an upgrade window should not cost a query and a warning for each
      # touch.
      #
      # Removed in 6.1, once the backfill is a release behind.
      def define_transitional_actor_reader(name)
        transitional_actor_readers.module_eval do
          define_method(name) do
            return super() if self[:"#{name}_type"].present?

            id = self[:"#{name}_id"]
            return super() if id.blank?

            @transitional_actors ||= {}
            return @transitional_actors[name] if @transitional_actors.key?(name)

            Spree::Deprecation.warn(
              "#{self.class.name}##{name} resolved through #{Spree.admin_user_class} because " \
              "#{name}_type is blank. Run `rake spree:upgrade:backfill_actor_types`; the fallback " \
              'is removed in Spree 6.1.'
            )

            @transitional_actors[name] = Spree.admin_user_class.find_by(id: id)
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
