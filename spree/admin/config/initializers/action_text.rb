# Since Rails 7.1 we can't use ActionText::ContentHelper.allowed_tags << ... to add more allowed tags
# We need to configure the whole set ourselves, see: https://stackoverflow.com/a/77369507
# Default allowed tags and attributes are copied from the rails action text helper: https://github.com/rails/rails/blob/main/actiontext/app/helpers/action_text/content_helper.rb#L68

sanitizer_class = Rails::HTML::Sanitizer.best_supported_vendor.safe_list_sanitizer

ActionText::ContentHelper.allowed_tags = sanitizer_class.allowed_tags + [ActionText::Attachment.tag_name, 'figure', 'figcaption', 'iframe']
ActionText::ContentHelper.allowed_attributes = sanitizer_class.allowed_attributes + ActionText::Attachment::ATTRIBUTES + ['style']
