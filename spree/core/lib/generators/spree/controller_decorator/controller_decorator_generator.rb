module Spree
  # spree:controller_decorator — generate a decorator file for an existing
  # Spree controller. Mirrors the model_decorator generator but handles
  # arbitrary namespace depth (Spree::ProductsController,
  # Spree::Admin::ProductsController, Spree::Api::V3::Store::ProductsController).
  #
  # @example
  #   bin/rails g spree:controller_decorator Spree::ProductsController
  #     => app/controllers/spree/products_controller_decorator.rb
  #
  #   bin/rails g spree:controller_decorator Spree::Admin::ProductsController
  #     => app/controllers/spree/admin/products_controller_decorator.rb
  class ControllerDecoratorGenerator < Rails::Generators::NamedBase
    desc 'Creates a controller decorator for a Spree controller'

    argument :name, type: :string, required: true,
                    banner: 'Spree::ControllerName | Spree::Namespace::ControllerName'

    def self.source_paths
      paths = superclass.source_paths
      paths << File.expand_path('templates', __dir__)
      paths.flatten
    end

    def create_controller_decorator_file
      template 'controller_decorator.rb.tt',
               "app/controllers/#{file_path}_decorator.rb"
    end

    private

    # Strip a leading `Spree::` and split the remainder on `::`.
    # `"Spree::Admin::ProductsController"` => `["Admin", "ProductsController"]`
    def name_parts
      @name_parts ||= name.sub(/\ASpree::/, '').split('::').reject(&:empty?)
    end

    # The unqualified controller name — the last segment.
    def controller_name
      name_parts.last
    end

    # The namespace segments above the controller, joined as a constant
    # chain. Empty string when the controller sits directly under Spree.
    def namespace_chain
      name_parts[0..-2].join('::')
    end

    # The decorator module name.
    def decorator_name
      "#{controller_name}Decorator"
    end

    # Path under app/controllers/, including the `spree/` root.
    def file_path
      ['spree', *name_parts.map(&:underscore)].join('/')
    end

    # Fully-qualified `Spree::Foo::Bar.prepend Spree::Foo::BarDecorator`.
    def prepend_invocation
      target = "Spree::#{name_parts.join('::')}"
      module_chain = ['Spree', *name_parts[0..-2], decorator_name].join('::')
      "#{target}.prepend #{module_chain}"
    end
  end
end
