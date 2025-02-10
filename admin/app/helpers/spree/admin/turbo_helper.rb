module Spree
  module Admin
    module TurboHelper
      def turbo_close_modal(modal_id = nil)
        modal_id ||= 'modal'

        turbo_stream.replace :modal_scripts do
          turbo_frame_tag :modal_scripts do
            javascript_tag do
              raw <<~JS
                if (document.querySelector('##{modal_id}')) {
                  window.$("##{modal_id}").modal('hide');
                }
              JS
            end
          end
        end
      end

      def turbo_render_alerts
        turbo_stream.replace :alerts do
          render 'spree/admin/shared/alerts'
        end
      end

      def turbo_save_button_tag(label = Spree.t('actions.save'), opts = {}, &block)
        opts[:class] ||= 'btn btn-primary text-center'
        opts[:class] << ' d-flex align-items-center justify-content-center' if opts[:class].exclude?('d-block') && opts[:class].exclude?('d-flex')

        opts['data-turbo-submits-with'] ||= "#{content_tag(:span, '', class: 'spinner-border spinner-border-sm mr-2', role: 'status')}Saving..."
        opts['data-enable-button-target'] = 'button'

        if block_given?
          button_tag opts, &block
        else
          button_tag label, opts
        end
      end
    end
  end
end
