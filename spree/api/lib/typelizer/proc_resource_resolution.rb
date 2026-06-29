module Typelizer
  module ProcResourceResolution
    # V3 serializers declare association resources lazily as `proc { Spree.api.x_serializer }`
    # so host-app overrides registered in initializers are respected at render time. Alba
    # calls the proc per object, but Typelizer introspects the resource as a class. Resolve
    # the proc to its serializer class so schema generation works for lazy associations.
    def interface_for(serializer_class)
      serializer_class = serializer_class.call if serializer_class.is_a?(Proc)
      super
    end
  end
end

Typelizer::WriterContext.prepend(Typelizer::ProcResourceResolution)
