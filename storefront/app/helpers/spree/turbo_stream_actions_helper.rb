module Spree
  module TurboStreamActionsHelper
    def slideover_open(slideover_name, target)
      turbo_stream_action_tag "#{slideover_name}:open", target: target
    end

    def search_suggestions_close
      turbo_stream_action_tag 'search-suggestions:close'
    end

    ::Turbo::Streams::TagBuilder.prepend(self)
  end
end
