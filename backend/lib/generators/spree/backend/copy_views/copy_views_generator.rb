module Spree
  module Backend
    class CopyViewsGenerator < Rails::Generators::Base
      desc 'Copies views from spree backend to your application'

      def self.source_paths
        [File.expand_path('../../../../../../app/', __FILE__)]
      end

      def copy_views
        directory 'views', './app/views'
      end
    end
  end
end
