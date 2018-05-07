module Spree
  if Rails.application.config.use_paperclip
    ActiveSupport::Deprecation.warn(<<-EOS, caller)
     Paperclip support is deprecated, and will be removed in Spree 4.0.
     Please migrate to ActiveStorage, to avoid problems after update
     https://github.com/thoughtbot/paperclip/blob/master/MIGRATING.md
    EOS
    Paperclip.interpolates :viewable_id do |attachment, _style|
      attachment.instance.viewable_id
    end
  end

  class Asset < Spree::Base
    include Support::ActiveStorage unless Rails.application.config.use_paperclip

    belongs_to :viewable, polymorphic: true, touch: true
    acts_as_list scope: [:viewable_id, :viewable_type]
  end
end
