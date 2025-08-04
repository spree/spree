require 'rails/generators'

module Spree
  module Admin
    module Generators
      class ScaffoldGenerator < Rails::Generators::Base
        desc 'Generates Spree admin dashboard scaffold for resource'

        def self.source_paths
          [
            File.expand_path('templates', __dir__),
            File.expand_path('../templates', "../#{__FILE__}"),
            File.expand_path('../templates', "../../#{__FILE__}")
          ]
        end

        def scaffold
          resource_name = args.first # eg. Spree::Property

          plural_name = resource_name.demodulize.underscore.pluralize # eg. properties
          singular_name = resource_name.demodulize.underscore # eg. property

          mkdir_p "app/views/spree/admin/#{plural_name}"

          # controller
          template 'controller.rb', "app/controllers/spree/admin/#{plural_name}_controller.rb"

          # views
          template 'views/index.html.erb', "app/views/spree/admin/#{plural_name}/index.html.erb"
          template 'views/new.html.erb', "app/views/spree/admin/#{plural_name}/new.html.erb"
          template 'views/edit.html.erb', "app/views/spree/admin/#{plural_name}/edit.html.erb"

          # partials
          template 'views/_table_header.html.erb', "app/views/spree/admin/#{plural_name}/_table_header.html.erb"
          template 'views/_table_row.html.erb', "app/views/spree/admin/#{plural_name}/_table_row.html.erb"
          template 'views/_filters.html.erb', "app/views/spree/admin/#{plural_name}/_filters.html.erb"
          template 'views/_form.html.erb', "app/views/spree/admin/#{plural_name}/_form.html.erb"
        end
      end
    end
  end
end
