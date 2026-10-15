module Spree
  # Adds an extension's own methods, associations, scopes and validations to
  # core models without a decorator.
  #
  # An extension writes an ordinary concern and registers it against the
  # model by name. Spree includes it, so the model's own methods still win:
  # an extension adds to a model, it never replaces what the model does.
  # A concern that would shadow a method, attribute or association the model
  # already has is refused at boot, naming both, where a decorator would
  # overwrite it quietly.
  #
  # Registrations are kept as names and included again each time code is
  # reloaded, so development reloading keeps them.
  #
  # @example
  #   Spree.model_extensions.add('Spree::Product', 'MyExtension::ProductWarranty')
  #   Spree.model_extensions.add(:user, 'MyExtension::UserWarranties')
  class ModelExtensions
    class Conflict < StandardError; end

    # The configured user classes, which an extension cannot know by name.
    USER_MODELS = { user: -> { Spree.customer_class }, admin_user: -> { Spree.admin_user_class } }.freeze

    def initialize
      @extensions = Hash.new { |hash, key| hash[key] = [] }
      @prepared = false
    end

    # @param model [String, Symbol] the model's class name, e.g. +'Spree::Product'+, or +:user+ / +:admin_user+
    # @param extension [String, Module] the concern to include
    # @raise [ArgumentError] for a symbol other than +:user+ and +:admin_user+
    # @raise [Conflict] when the concern would shadow something the model already has
    # @return [void]
    def add(model, extension)
      key = key_for(model)
      name = extension.is_a?(Module) ? extension.name : extension.to_s
      @extensions[key] |= [name]
      apply_to(key, name) if @prepared
    end

    # @param model [String, Symbol]
    # @return [Array<String>] the concerns registered for the model
    def for(model)
      @extensions.fetch(key_for(model), []).dup
    end

    # Includes every registered concern. Spree runs it each time code is
    # loaded; a registration made after that is included straight away.
    #
    # @return [void]
    def apply
      @prepared = true
      @extensions.each { |key, names| names.each { |name| apply_to(key, name) } }
    end

    private

    def key_for(model)
      return model.to_s unless model.is_a?(Symbol)
      return model if USER_MODELS.key?(model)

      raise ArgumentError, "#{model} is not a model: pass its class name, or :user or :admin_user"
    end

    def resolve(key)
      key.is_a?(Symbol) ? USER_MODELS.fetch(key).call : key.constantize
    end

    def apply_to(key, name)
      model = resolve(key)
      extension = name.constantize
      return if model.include?(extension)

      refuse_shadowed_methods!(model, extension)
      existing = model.instance_methods
      reflections = model.reflections.dup
      model.include(extension)

      # Associations are declared in the concern's +included+ block, so they
      # are only known once it has run: one it declared or redeclared there
      # must not take a name the model already answers to.
      declared = model.reflections.reject { |name, reflection| reflections[name].equal?(reflection) }.keys
      shadowed = declared.find { |name| reflections.key?(name) || existing.include?(name.to_sym) }
      raise_conflict(model, extension, shadowed) if shadowed
    end

    def refuse_shadowed_methods!(model, extension)
      methods = extension.instance_methods(false) + extension.private_instance_methods(false)
      taken = methods.find { |method| model.method_defined?(method) || model.private_method_defined?(method) || attribute?(model, method) }
      raise_conflict(model, extension, taken) if taken

      return unless extension.const_defined?(:ClassMethods, false)

      taken = extension::ClassMethods.instance_methods(false).find { |method| model.respond_to?(method, true) }
      raise_conflict(model, extension, taken) if taken
    end

    # Attribute methods are generated on first use, so a column is checked by
    # name. Without a database to read the columns from, as when assets are
    # compiled, there are none to shadow.
    def attribute?(model, method)
      model.attribute_names.include?(method.to_s.delete_suffix('='))
    rescue ActiveRecord::ActiveRecordError
      false
    end

    def raise_conflict(model, extension, method)
      raise Conflict, "#{extension.name} would replace #{model.name}##{method}, which the model already has"
    end
  end
end
