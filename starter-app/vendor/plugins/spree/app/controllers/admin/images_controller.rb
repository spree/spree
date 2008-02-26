class Admin::ImagesController < Admin::BaseController

  def new
    @image = Image.new
    render :layout => false
  end

  # delete the variation (ajax call from either product or category edit screen)
  def delete
    image = Image.find(params[:id])
    viewable = image.viewable
    image.destroy
    render :partial => 'shared/images', :locals => {:viewable => viewable}
  end
end
