class Admin::ProductPropertiesController < Admin::ResourceProductController
  before_filter :find_properties

  private

  def find_properties
    @properties = Property.all.map(&:name).join(" ")
  end
end
