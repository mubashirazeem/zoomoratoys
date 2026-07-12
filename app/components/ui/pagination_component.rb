# frozen_string_literal: true

# Generic pager for any Kaminari-paginated scope. Content-agnostic by
# design (per COMPONENT_GUIDELINES.md's ui/ convention) — the caller
# supplies how to build a page's URL via a block, so this isn't hardcoded
# to the Shop page even though that's its first use.
class Ui::PaginationComponent < ViewComponent::Base
  WINDOW = 2

  def initialize(scope:, &url_for_page)
    @scope = scope
    @url_for_page = url_for_page
  end

  def render?
    total_pages > 1
  end

  def current_page
    @scope.current_page
  end

  def total_pages
    @scope.total_pages
  end

  def url_for_page(page)
    @url_for_page.call(page)
  end

  # Page numbers to render, with nil standing in for an ellipsis gap — keeps
  # the pager a fixed width even once a catalog grows to hundreds of pages.
  def page_items
    pages = (1..total_pages).select { |p| p == 1 || p == total_pages || (p - current_page).abs <= WINDOW }

    result = []
    pages.each_cons(2) do |a, b|
      result << a
      result << nil if b - a > 1
    end
    result << pages.last
    result
  end
end
