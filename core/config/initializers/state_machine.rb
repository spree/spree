# frozen_string_literal: true

module MachineDecorator
  protected

  # Determines whether there's already a helper method defined within the
  # given scope.  This is true only if one of the owner's ancestors defines
  # the method and is further along in the ancestor chain than this
  # machine's helper module.
  def owner_class_ancestor_has_method?(scope, method)
    return false unless owner_class_has_method?(scope, method)

    superclasses = owner_class.ancestors.select { |ancestor| ancestor.is_a?(Class) }[1..-1]

    if scope == :class
      current = owner_class.singleton_class
      superclass = superclasses.first
    else
      current = owner_class
      superclass = owner_class.superclass
    end

    # Generate the list of modules that *only* occur in the owner class, but
    # were included *prior* to the helper modules, in addition to the
    # superclasses
    ancestors = current.ancestors - superclass.ancestors + superclasses
    ancestors = ancestors[ancestors.index(@helper_modules[scope])..-1].reverse

    # Search for for the first ancestor that defined this method
    ancestors.detect do |ancestor|
      ancestor = ancestor.singleton_class if scope == :class && ancestor.is_a?(Class)
      ancestor.method_defined?(method) || ancestor.private_method_defined?(method)
    end
  end
end

::StateMachines::Machine.prepend MachineDecorator
