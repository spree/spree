module Spree
  module Emails
    # Loads the partials templates pull in with `{% render 'spree/shared/line_item' %}`
    # from `spree/shared/_line_item.liquid`, following Rails' partial naming.
    class FileSystem
      # @param resolver [Spree::Emails::TemplateResolver]
      def initialize(resolver)
        @resolver = resolver
      end

      # @param name [String]
      # @return [String] the partial's source
      def read_template_file(name)
        partial = @resolver.find_partial(name.to_s)
        raise Liquid::FileSystemError, "No such email partial: #{name}" unless partial

        partial.body
      rescue Spree::Emails::TemplateResolver::InvalidKey
        raise Liquid::FileSystemError, 'Invalid email partial name'
      end
    end
  end
end
