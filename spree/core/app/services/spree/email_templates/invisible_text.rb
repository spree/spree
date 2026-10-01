module Spree
  module EmailTemplates
    # A template's text sits outside any MJML content component, so the email
    # would not show it. A Liquid error, so it is reported like one, with its line.
    class InvisibleText < Liquid::Error; end
  end
end
