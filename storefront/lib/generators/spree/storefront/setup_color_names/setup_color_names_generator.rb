require 'rails/generators'
require 'open-uri'
require 'fileutils'

module Spree
  module Storefront
    module Generators
      class SetupColorNamesGenerator < Rails::Generators::Base
        desc 'Downloads color names list from unpkg.com'

        def download_color_names
          say_status :downloading, 'color names list'
          FileUtils.mkdir_p('lib/assets')
          URI.open('https://unpkg.com/color-name-list/dist/colornames.json') do |remote_file|
            File.open('lib/assets/colornames.json', 'wb') do |local_file|
              local_file.write(remote_file.read)
            end
          end
        end
      end
    end
  end
end
