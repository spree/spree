class Admin::PrototypesController < Admin::BaseController
  def edit
    @prototype = find_prototype
    if request.xhr?
      render :partial => 'edit', :locals => { :properties_to_add => [],
                                              :properties_to_remove => [] }
    end
  end

  def update
    @prototype = find_prototype
    @prototype.update_attributes(params[:prototype])
    success = @prototype.save

    # deal with properties
    properties = params[:property]
    properties_to_add = []
    properties_to_remove = []
    if properties
      properties.each do |key, value|
        prop = Property.find(key)
        if value == 'add'
          @prototype.properties << prop if success
          properties_to_add << prop.id
        elsif value == 'remove'
          @prototype.properties.delete(prop) if success
          properties_to_remove << prop.id
        end
      end
    end

    if success
      if request.xhr?
        render :partial => 'success', :status => 201
      else
        redirect_to :index
      end
    else
      if request.xhr?
        render :partial => 'edit', :locals => { :properties_to_add => properties_to_add,
                                                :properties_to_remove => properties_to_remove }
      else
        redirect_to :index
      end
    end
  end

  def list
    render :partial => 'list'
  end

  private
  def find_prototype
    prototype = Prototype.find(params[:id]) if params[:id]
    prototype = Prototype.new(params[:prototype]) unless prototype
    prototype
  end

end
