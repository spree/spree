module Spree
  module Admin
    class ImageSettingsController < Spree::Admin::BaseController
      def edit
        @styles = ActiveSupport::JSON.decode(Spree::Config[:attachment_styles])
        @headers = ActiveSupport::JSON.decode(Spree::Config[:s3_headers])
      end

      def update
        update_styles(params)
        update_headers(params) if Spree::Config[:use_s3]

        Spree::Config.set(params[:preferences])
        update_paperclip_settings

        respond_to do |format|
          format.html {
            flash[:success] = t(:image_settings_updated)
            redirect_to spree.edit_admin_image_settings_path
          }
        end
      end


      private

      def update_styles(params)
        params[:new_attachment_styles].each do |index, style|
          params[:attachment_styles][style[:name]] = style[:value] unless style[:value].empty?
        end if params[:new_attachment_styles].present?

        styles = params[:attachment_styles]

        Spree::Config[:attachment_styles] = ActiveSupport::JSON.encode(styles) unless styles.nil?
      end

      def update_headers(params)
        params[:new_s3_headers].each do |index, header|
          params[:s3_headers][header[:name]] = header[:value] unless header[:value].empty?
        end if params[:new_s3_headers].present?

        headers = params[:s3_headers]

        Spree::Config[:s3_headers] = ActiveSupport::JSON.encode(headers) unless headers.nil?
      end

      def update_paperclip_settings
        if Spree::Config[:use_s3]
          s3_creds = { :access_key_id => Spree::Config[:s3_access_key], :secret_access_key => Spree::Config[:s3_secret], :bucket => Spree::Config[:s3_bucket] }
          Spree::Image.attachment_definitions[:attachment][:storage] = :s3
          Spree::Image.attachment_definitions[:attachment][:s3_credentials] = s3_creds
          Spree::Image.attachment_definitions[:attachment][:s3_headers] = ActiveSupport::JSON.decode(Spree::Config[:s3_headers])
          Spree::Image.attachment_definitions[:attachment][:bucket] = Spree::Config[:s3_bucket]
        else
          Spree::Image.attachment_definitions[:attachment].delete :storage
        end

        Spree::Image.attachment_definitions[:attachment][:styles] = ActiveSupport::JSON.decode(Spree::Config[:attachment_styles])
        Spree::Image.attachment_definitions[:attachment][:path] = Spree::Config[:attachment_path]
        Spree::Image.attachment_definitions[:attachment][:default_url] = Spree::Config[:attachment_default_url]
        Spree::Image.attachment_definitions[:attachment][:default_style] = Spree::Config[:attachment_default_style]
      end
    end
  end
end

