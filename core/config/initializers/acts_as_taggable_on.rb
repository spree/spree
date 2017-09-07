require 'acts-as-taggable-on'

ActsAsTaggableOn::Tag.class_eval do
  self.table_name_prefix = 'spree_'
end

ActsAsTaggableOn::Tagging.class_eval do
  self.table_name_prefix = 'spree_'
end
