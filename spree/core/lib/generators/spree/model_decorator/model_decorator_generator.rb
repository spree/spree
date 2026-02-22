module Spree
  class ModelDecoratorGenerator < Rails::Generators::NamedBase
    desc 'Creates a model decorator for a Spree model'

    argument :name, type: :string, required: true, banner: 'Spree::ModelName'

    def self.source_paths
      paths = superclass.source_paths
      paths << File.expand_path('templates', __dir__)
      paths.flatten
    end

    def create_model_decorator_file
      template 'model_decorator.rb.tt', "app/models/#{file_path}_decorator.rb"
    end

    private

    # Returns the model name without the Spree:: prefix
    # e.g., "Spree::Product" => "Product", "Product" => "Product"
    def model_name
      name.sub(/^Spree::/, '').classify
    end

    # Returns the decorator module name
    # e.g., "Spree::Product" => "ProductDecorator"
    def decorator_name
      "#{model_name}Decorator"
    end

    # Returns the file path for the decorator
    # e.g., "Spree::Product" => "spree/product", "Product" => "spree/product"
    def file_path
      "spree/#{model_name.underscore}"
    end
  end
end
