require 'haml/helpers/action_view_mods'

if defined?(ActionView)
  module Haml
    module Helpers
      # This module contains various useful helper methods
      # that either tie into ActionView or the rest of the ActionPack stack,
      # or are only useful in that context.
      # Thus, the methods defined here are only available
      # if ActionView is installed.
      module ActionViewExtensions
        # Returns a value for the "class" attribute
        # unique to this controller/action pair.
        # This can be used to target styles specifically at this action or controller.
        # For example, if the current action were EntryController#show,
        #
        #   %div{:class => page_class} My Div
        #
        # would become
        #
        #   <div class="entry show">My Div</div>
        #
        # Then, in a stylesheet
        # (shown here as Sass),
        # you could refer to this specific action:
        #
        #   .entry.show
        #     :font-weight bold
        #
        # or to all actions in the entry controller:
        #
        #   .entry
        #     :color #00f
        #
        def page_class
          controller.controller_name + " " + controller.action_name
        end

        # :stopdoc:
        alias_method :generate_content_class_names, :page_class
        # :startdoc:
      end
    end
  end
end
