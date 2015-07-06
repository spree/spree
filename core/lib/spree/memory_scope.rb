module Spree
  # Memory scope library namespace
  #
  # This module allows to define memory scopes. Scopes that are read against
  # a base relation, avoiding duplicate loads of the same object that can result
  # in performance degeration via N+1 lazy loads per duplicate and the need to #reload
  # entire object trees.
  #
  # The exposed Memory::Scope object intentionally only implements the subset of the AR API
  # spree actually uses on adjustment associations / scopes right now.
  #
  class MemoryScope
    include Enumerable, Adamantium::Flat, Concord.new(:base, :predicate)

    # Raised for unsupported finder interfaces
    class UnsupportedInterfaceError < NotImplementedError
    end

    TAUTOLOGY = ->(_object) { true }

    delegate :create!, :build, to: :base

    # Define a memory scope capturing the block as predicate
    #
    # @param [Symbol] name
    #   the name of the memory scope
    #
    # @return [undefined]
    #
    # @api private
    def self.memory_scope(name, &predicate)
      define_method(name) { restrict(&predicate) }
    end
    private_class_method :memory_scope

    # Define a memory scope comparing record attribute with value
    #
    # Useful shorthand to deduplicate multiple definition of scopes that
    # test an attribute value against a static right hand side.
    #
    # @param [Symbol] name
    #   the name of the memory scope
    # @param [Symbol] attribute_name
    #   the name of the attribute to compare with
    # @param [Object] value
    #   the value of the attribute to compare to
    #
    # @return [undefined]
    #
    # @api private
    def self.memory_scope_attribute_value(name, attribute_name, value)
      memory_scope(name) do |object|
        object.public_send(attribute_name).eql?(value)
      end
    end
    private_class_method :memory_scope_attribute_value

    # Construct a memory scope
    #
    # @param [ActiveRecord::Relation] _base
    #   the base relation that gets scoped
    # @param [#call] _predicate
    #   the predicate used to filter scope
    #
    # @return [undefined]
    #
    # @api private
    def self.new(_base, _predicate = TAUTOLOGY)
      super
    end

    # Return array representation
    #
    # @return [Array]
    #
    # @api private
    alias_method :to_ary, :to_a

    # Enumerate records of scope
    #
    # @return [self]
    #   if block given
    #
    # @return [Enumerator]
    #   otherwise
    #
    # @api private
    def each(&block)
      return to_enum unless block
      records.each(&block)
      self
    end

    # Return a restricted scope
    #
    # @param [Hash] attributes
    #   the attributes to filter records by
    #
    # @return [MemoryScope]
    #
    # @api private
    def where(*arguments)
      conditions = extract_where_conditions(arguments)
      conditions.reduce(self) do |scope, (name, value)|
        scope.restrict { |record| record.public_send(name).eql?(value) }
      end
    end

    # Return a restricted scope
    #
    # @return [MemoryScope]
    #
    # @api private
    def restrict
      self.class.new(
        base,
        ->(object) { predicate.call(object) && yield(object) }
      )
    end

    # Test if any matching record exists
    #
    # @return [Boolean]
    #
    # @api private
    def exists?
      any?
    end

    # Test if scope has no records
    #
    # @return [Boolean]
    #
    # @api private
    def empty?
      !exists?
    end

    # Sum up record attributes
    #
    # @param [Symbol] attribute_name
    #   the attribute name to sum up
    #
    # @return [Object]
    #
    # @api private
    def sum(attribute_name)
      map(&attribute_name).sum
    end

    # Update all records of scope
    #
    # TODO: Avoid #update_columns on each object. And call #update_all on a relation restricted to record ids.
    #       This would require to update the records attributes in a way dirty tracking does not trigger.
    #
    # @param [Hash] attributes
    #
    # @return [Fixnum]
    #   the amount of updated rows
    #
    # @api private
    def update_all(attributes)
      count { |object| object.update_columns(attributes) }
    end

    # Destroy all records of scope
    #
    # @return [Enumerable<Object>]
    #   the collection of destroyed objects
    #
    # @api private
    def destroy_all
      command_all(__method__)
    end

    # Delete all records of scope
    #
    # @return [Fixnum]
    #   the number of rows affected
    #
    # @api private
    def delete_all
      command_all(__method__)
    end

    # Find a record based on id
    #
    # @param [Fixnum, String] id
    #   the record id will be coerced to an integer
    #
    # @return [Object]
    #   when object matching id was found
    #
    # @raise [Activerecord::RecordNotFound]
    #   otherwise
    #
    # @api private
    def find(id)
      id = Integer(id)
      detect { |record| record.id.equal?(id) } or
        raise ActiveRecord::RecordNotFound,"Couldn't find #{base.proxy_association.reflection.inverse_of.active_record} with 'id'=#{id}"
    end

    # Return an array of record attribute values
    #
    # @param [Symbol] attribute_name
    #
    # @return [Array<Object>]
    #
    # @api private
    def pluck(attribute_name)
      map(&attribute_name)
    end

  private

    # Execute a command against all records and reset the relation
    #
    # TODO: Avoid #reset via removing records from proxy directly.
    #
    # @param [Symbol] method_name
    #
    # @return [Object]
    #
    # @api private
    def command_all(method_name)
      base.where(id: pluck(:id)).public_send(method_name).tap { base.reset }
    end

    # Extract supported #where conditions
    #
    # @param [Array<Object>] arguments
    #
    # @return [Hash]
    #   in case conditions could be extracted
    #
    # @raise [UnsupportedInterfaceError]
    #   otherwise
    #
    # @api private
    def extract_where_conditions(arguments)
      raise UnsupportedInterfaceError, "#where interface with #{arguments.length} argument is unsupported" unless arguments.one?

      argument = arguments.first
      unless argument.instance_of?(Hash)
        raise UnsupportedInterfaceError, '#where interface with non Hash argument is unsupported'
      end

      argument
    end

    # The filtered and sorted records
    #
    # @return [Array]
    #
    # @api private
    def records
      base
        .select  { |record| !record.destroyed? && predicate.call(record) }
        .sort_by { |record| [record.created_at, record.id]               }
    end

  end # MemoryScope
end # Spree
