module Spree
  class DigitalLinksController < StoreController
    def show
      if digital_link.authorize!
        if defined?(ActiveStorage::Service::DiskService) && ActiveStorage::Blob.service.instance_of?(ActiveStorage::Service::DiskService)
          send_file(
            ActiveStorage::Blob.service.path_for(attachment.key),
            filename: digital_link.filename.to_s,
            type: digital_link.content_type.to_s,
            status: :ok
            ) and return
        else
          redirect_to attachment.url(
            expires_in: current_store.digital_asset_link_expire_time.seconds,
            disposition: 'attachment',
            host: current_store.formatted_url_or_custom_domain
          ) and return
        end
      end

      flash[:error] = Spree.t(:digital_link_unauthorized)
      redirect_to spree.order_path(digital_link.order)
    end

    private

    def digital_link
      @digital_link ||= DigitalLink.find_by!(token: params[:id])
    end

    def attachment
      @attachment ||= digital_link.digital.attachment
    end
  end
end
