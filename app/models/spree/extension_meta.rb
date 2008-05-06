class Spree::ExtensionMeta < ActiveRecord::Base
  set_table_name "extension_meta"
  validates_presence_of :name
  validates_uniqueness_of :name
end