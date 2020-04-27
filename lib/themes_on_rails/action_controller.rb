module ThemesOnRails
  class ActionController
    attr_reader :theme_name

    class << self
      def apply_theme(controller_class, theme, options={})
        filter_method = before_filter_method(options)
        options       = options.slice(:only, :except)

        # set layout
        controller_class.class_eval do
          define_method :layout_from_theme do
            theme_instance.theme_name
          end

          define_method :theme_instance do
            @theme_instance ||= ThemesOnRails::ActionController.new(self, theme)
          end

          define_method :current_theme do
            theme_instance.theme_name
          end

          private :layout_from_theme, :theme_instance
          layout  :layout_from_theme, options
          helper_method :current_theme
        end

        controller_class.send(filter_method, options) do |controller|

          # #prepend_view_path leaks memory when called with a String argument, see https://www.spacevatican.org/2019/5/4/debugging-a-memory-leak-in-a-rails-app/. To alleviate this, we check if there are precompiled resolvers available and use them instead. String path prepending is only used as a last resort.
          if defined?(THEMES_ON_RAILS_RESOLVERS) && THEMES_ON_RAILS_RESOLVERS.is_a?(Hash)
            controller.prepend_view_path THEMES_ON_RAILS_RESOLVERS.fetch(theme_instance.theme_name, theme_instance.theme_name)
          else
            controller.prepend_view_path theme_instance.theme_view_path
          end

          # liquid file system
          Liquid::Template.file_system = Liquid::Rails::FileSystem.new(theme_instance.theme_view_path) if defined?(Liquid::Rails)
        end
      end

    private

      def before_filter_method(options)
        case Rails::VERSION::MAJOR
        when 3
          options.delete(:prepend) ? :prepend_before_filter : :before_filter
        when 4, 5
          options.delete(:prepend) ? :prepend_before_action : :before_action
        end
      end
    end

    def initialize(controller, theme)
      @controller = controller
      @theme_name = _theme_name(theme)
    end

    def theme_view_path
      "#{prefix_path}/#{@theme_name}/views"
    end

    def prefix_path
      "#{Rails.root}/app/themes"
    end

    private

      def _theme_name(theme)
        case theme
        when String     then theme
        when Proc       then theme.call(@controller).to_s
        when Symbol     then @controller.respond_to?(theme, true) ? @controller.send(theme).to_s : theme.to_s
        else
          raise ArgumentError,
            "String, Proc, or Symbol, expected for `theme'; you passed #{theme.inspect}"
        end
      end
  end
end
