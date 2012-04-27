module Refinery
  module Admin
    class PagesController < Refinery::AdminController
      cache_sweeper Refinery::PageSweeper

      crudify :'refinery/page',
              :order => "lft ASC",
              :include => [:translations, :children],
              :paging => false

      after_filter lambda{::Refinery::Page.expire_page_caching}, :only => [:update_positions]

      before_filter :load_valid_templates, :only => [:edit, :new]

      before_filter :restrict_access, :only => [:create, :update, :update_positions, :destroy],
                    :if => proc { Refinery.i18n_enabled? }

      def new
        @page = Refinery::Page.new(params.except(:controller, :action, :switch_locale))
        Refinery::Pages.default_parts_for(@page).each_with_index do |page_part, index|
          @page.parts << Refinery::PagePart.new(:title => page_part, :position => index)
        end
      end

      def children
        @page = find_page
        render :layout => false
      end

      def index_with_manual_children_preloading
        index_without_manual_children
        manually_associate_children(@pages)
      end
      alias_method_chain :index, :manual_children_preloading

    protected

      def find_page
        @page = Refinery::Page.find_by_path_or_id(params[:path], params[:id])
      end
      alias_method :page, :find_page

      def find_all_pages(conditions = nil)
        @pages = Page.where(conditions).includes(:translations).order("lft ASC")
      end

      # Preloading children via Page.includes(:children) is inefficient and doesn't work beyond
      # the first level of nesting (ie: @pages.first.children.first.children starts issuing queries again).
      def manually_associate_children(pages)
        parent_id_grouped = pages.group_by(&:parent_id)
        # code taken almost verbatim from AR::Associations::Preloader::CollectionAssociation
        pages.each do |page|
          children = parent_id_grouped[page.id] || []
          association = page.association(:children)
          association.loaded!
          association.target.concat(children)
          children.each {|child| association.set_inverse_instance(child)}
        end
      end

      # We can safely assume ::Refinery::I18n is defined because this method only gets
      # Invoked when the before_filter from the plugin is run.
      def globalize!
        unless action_name.to_s == 'index'
          super

          # Needs to take into account that slugs are translated now
          # # Check whether we need to override e.g. on the pages form.
          # unless params[:switch_locale] || @page.nil? || @page.new_record? || @page.slugs.where({
          #   :locale => Refinery::I18n.current_locale
          # }).empty?
          #   @page.slug = @page.slugs.first if @page.slug.nil? && @page.slugs.any?
          #   Thread.current[:globalize_locale] = @page.slug.locale if @page.slug
          # end
        else
          # Always display the tree of pages from the default frontend locale.
          Thread.current[:globalize_locale] = params[:switch_locale].try(:to_sym) || Refinery::I18n.default_frontend_locale
        end
      end

      def load_valid_templates
        @valid_layout_templates = Refinery::Pages.layout_template_whitelist &
                                  Refinery::Pages.valid_templates('app', 'views', '{layouts,refinery/layouts}', '*html*')

        @valid_view_templates = Refinery::Pages.view_template_whitelist &
                                Refinery::Pages.valid_templates('app', 'views', '{pages,refinery/pages}', '*html*')
      end

      def restrict_access
        if current_refinery_user.has_role?(:translator) && !current_refinery_user.has_role?(:superuser) &&
             (params[:switch_locale].blank? || params[:switch_locale] == Refinery::I18n.default_frontend_locale.to_s)
          flash[:error] = t('translator_access', :scope => 'refinery.admin.pages')
          redirect_to refinery.admin_pages_path
        end

        return true
      end

    end
  end
end
