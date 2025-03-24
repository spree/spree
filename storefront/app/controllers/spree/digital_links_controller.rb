module Spree
  class DigitalLinksController < StoreController
    def show
      if digital_link.authorize!
        mark_shipment_as_fullfiled if digital_link.access_counter == 1

        if defined?(ActiveStorage::Service::DiskService) && ActiveStorage::Blob.service.instance_of?(ActiveStorage::Service::DiskService)
          send_file(
            ActiveStorage::Blob.service.path_for(attachment.key),
            filename: digital_link.filename.to_s,
            type: digital_link.content_type.to_s,
            status: :ok
            ) and return
        else
          redirect_to attachment.url(
            expires_in: current_store.preferred_digital_asset_link_expire_time.seconds,
            disposition: 'attachment'
          ), allow_other_host: true and return
        end
      end

      flash[:error] = Spree.t(:digital_link_unauthorized)
      redirect_to spree.order_path(digital_link.order)
    end

    private

    def mark_shipment_as_fullfiled
      ActiveRecord::Base.connected_to(role: :writing) do
        Spree::Shipment.transaction do
          shipments.each(&:ship)
        end
      end
    end

    def digital_link
      @digital_link ||= current_store.digital_links.find_by!(token: params[:id])
    end

    def shipments
      @shipments ||= digital_link.line_item.shipments.digital_delivery
    end

    def attachment
      @attachment ||= digital_link.digital.attachment
    end
  end
end
