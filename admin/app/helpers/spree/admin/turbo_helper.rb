module Spree
  module Admin
    module TurboHelper
      def turbo_close_modal(modal_id = nil)
        Spree::Deprecation.warn('turbo_close_modal is deprecated and will be removed in Spree 5.5. Use turbo_close_dialog instead.')

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

      def turbo_close_dialog
        turbo_stream.replace 'main-dialog' do
          render 'spree/admin/shared/dialog'
        end
      end

      def turbo_close_drawer
        turbo_stream.replace 'drawer-dialog' do
          render 'spree/admin/shared/drawer'
        end
      end

      def turbo_render_alerts(frame_name = :alerts)
        turbo_stream.replace frame_name do
          render 'spree/admin/shared/alerts', frame_name: frame_name
        end
      end

      def turbo_save_button_tag(label = Spree.t('actions.save'), opts = {}, &block)
        opts[:class] ||= 'btn btn-primary text-center'
        opts[:class] << ' flex items-center justify-center' if opts[:class].exclude?('block') && opts[:class].exclude?('flex')

        opts['data-turbo-submits-with'] ||= "#{content_tag(:span, '', class: 'inline-block w-4 h-4 border-2 border-current border-r-transparent rounded-full animate-spin', role: 'status')}"
        opts['data-enable-button-target'] = 'button'
        if opts['data-controller'].present?
          opts['data-controller'] += ' turbo-submit-button'
        else
          opts['data-controller'] = 'turbo-submit-button'
        end

        if block_given?
          button_tag opts, &block
        else
          button_tag label, opts
        end
      end
    end
  end
end
