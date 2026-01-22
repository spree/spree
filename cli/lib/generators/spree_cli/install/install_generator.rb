require 'rails/generators'

module SpreeCli
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Installs Spree CLI binstub into your application'

      def create_binstub
        template 'bin/spree', 'bin/spree'
        chmod 'bin/spree', 0o755
      end

      def show_post_install_message
        say_status :installed, 'bin/spree'
        say ''
        say 'You can now run Spree CLI commands using:'
        say '  bin/spree version'
        say '  bin/spree extension my_extension'
        say ''
      end
    end
  end
end
