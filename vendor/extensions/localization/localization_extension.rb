# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class LocalizationExtension < Spree::Extension
  version "0.1.1"
  description "Localization support for Spree"
  url "http://support.spreehq.org/wiki/1/I18n"

  def activate
    # load extensions lang/ui
    Globalite.add_localization_source(File.join(SPREE_ROOT, 'vendor/extensions/**/lang/ui'))

    ApplicationController.class_eval do
      include Localization
      helper_method :t
      helper_method :flag
    end

    User.class_eval do
      include Localization::UserPreferences
    end

    # admin.tabs.add "Localization", "/admin/localization", :after => "Layouts", :visibility => [:all]
  end
end