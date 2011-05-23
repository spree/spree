class Admin::ProductPropertiesController < Admin::ResourceController
  belongs_to :product, :find_by => :permalink
  before_filter :find_properties

  private

  def find_properties
    @properties = Property.all.map(&:name).join(" ")
  end
end
