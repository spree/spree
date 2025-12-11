module Spree
  module Admin
    module AvatarsHelper
      AVATAR_GRADIENTS = [
        'bg-gradient-to-br from-indigo-500 to-purple-600',
        'bg-gradient-to-br from-pink-400 to-rose-500',
        'bg-gradient-to-br from-blue-400 to-cyan-400',
        'bg-gradient-to-br from-emerald-400 to-teal-400',
        'bg-gradient-to-br from-rose-400 to-yellow-300',
        'bg-gradient-to-br from-teal-200 to-pink-200',
        'bg-gradient-to-br from-rose-300 to-pink-200',
        'bg-gradient-to-br from-orange-200 to-orange-400',
        'bg-gradient-to-br from-violet-500 to-fuchsia-500',
        'bg-gradient-to-br from-amber-400 to-orange-500',
      ].freeze

      def avatar_gradient_class(identifier)
        index = Digest::MD5.hexdigest(identifier.to_s)[0..7].to_i(16) % AVATAR_GRADIENTS.length
        AVATAR_GRADIENTS[index]
      end

      # render an avatar for a user
      # if user doesn't have an avatar, the user's initials will be displayed on a rounded-lg  background
      # @param user [Spree::User] the user to render the avatar for
      # @param options [Hash] the options for the avatar
      # @option options [Integer] :width the width of the avatar, default: 128
      # @option options [Integer] :height the height of the avatar, default: 128
      # @option options [String] :class the CSS class(es) of the avatar, default: 'avatar'
      # @return [String] the avatar
      def render_avatar(user, options = {})
        return unless user.present?

        options[:width] ||= 128
        options[:height] ||= 128
        options[:class] ||= 'rounded-full flex items-center justify-center text-white text-lg'

        if user.respond_to?(:avatar) && user.avatar.attached? && user.avatar.variable?
          spree_image_tag(
            user.avatar,
            width: options[:width],
            height: options[:height],
            class: options[:class],
            style: "width: #{options[:width]}px; height: #{options[:height]}px;"
          )
        else
          gradient = avatar_gradient_class(user.email)
          content_tag :div, user.name&.initials,
                      class: "#{gradient} #{options[:class]}",
                      style: "width: #{options[:width]}px; height: #{options[:height]}px;"
        end
      end
    end
  end
end
