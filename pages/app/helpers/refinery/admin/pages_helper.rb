module Refinery
  module Admin
    module PagesHelper
      def parent_id_nested_set_options(page)
        pages = []
        nested_set_options(::Refinery::Page, page) {|i| pages << i}
        # page.title needs the :translations association, doing something like
        # nested_set_options(::Refinery::Page.includes(:translations), page) doesn't work
        ActiveRecord::Associations::Preloader.new(pages, :translations).run
        pages.map {|i, id| ["#{'-' * i.level} #{i.title}", id]}
      end
    end
  end
end
