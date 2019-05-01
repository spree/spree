# https://github.com/nesquena/rabl/pull/723
module ActionView
  module Template::Handlers
    class Rabl
      class_attribute :default_format, default: :json

      def self.call(_template, source)
        %{ ::Rabl::Engine.new(#{source.inspect}).
            apply(self, assigns.merge(local_assigns)).
            render }
      end
    end
  end
end

ActionView::Template.register_template_handler :rabl, ActionView::Template::Handlers::Rabl
