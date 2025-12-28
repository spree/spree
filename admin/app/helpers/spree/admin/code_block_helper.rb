module Spree
  module Admin
    module CodeBlockHelper
      def code_block(code, options = {})
        options[:language] ||= 'json'
        options[:class] ||= 'm-0 block overflow-auto rounded-lg'

        content_tag :div, data: { controller: 'highlight' } do
          content_tag(:pre) do
            content_tag(:code, class: "language-#{options[:language]} #{options[:class]}", style: options[:style], data: { highlight_target: 'code' }) do
              code
            end
          end
        end
      end
    end
  end
end
