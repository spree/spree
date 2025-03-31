module Spree
  class ColorNames
    include Singleton

    class << self
      def colors
        @colors ||= Rails.cache.fetch('color_names', expires_in: 1.day) do
          file_path = File.join(Spree::Storefront::Engine.root, 'vendor', 'colornames.json')

          if File.exist?(file_path)
            JSON.parse(File.read(file_path))
          else
            []
          end
        end
      end

      def colors_cache
        @colors_cache ||= colors.inject({}) do |hash, color|
          hash[color['name'].downcase] = color
          hash
        end
      end

      def find_by_name(name)
        colors_cache[name.downcase]
      end

      def split_by_color_name(name)
        multi_color_regex = /(\s+and\s+|\s*-\s*|\s*&\s*|\s*\+\s*|\s*\/\s*)/
        name.gsub(multi_color_regex, ',').split(',').map(&:strip)
      end
    end
  end
end
