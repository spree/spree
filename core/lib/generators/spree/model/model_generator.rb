require "rails/generators/active_record/model/model_generator"

module Spree
  class ModelGenerator < ActiveRecord::Generators::ModelGenerator

    def self.source_paths
      paths = superclass.source_paths
      paths << File.expand_path('templates', __dir__)
      paths.flatten
    end

    class_option :parent, type: :string, default: "Spree::Base", desc: "The parent class for the generated model"

    desc 'Creates a new Spree model'

    # Override to prevent module file from being created
    def create_module_file
      return
    end
  end
end
