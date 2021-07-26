module Spree
    module Api
        module V1
            class RolesController < Spree::Api::BaseController
                def index
                    @roles = Role.all
                    render :json => @roles
                end
            end
        end
    end
end
