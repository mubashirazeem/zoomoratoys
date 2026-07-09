# frozen_string_literal: true

# items: an ordered array of { label:, url: } hashes. The final item is
# rendered as the current page (no link, aria-current="page") whether or
# not it's given a url.
class Ui::BreadcrumbComponent < ViewComponent::Base
  Item = Struct.new(:label, :url, keyword_init: true)

  def initialize(items:)
    @items = items.map { |item| Item.new(**item) }
  end

  def items
    @items.each_with_index.map { |item, index| [ item, index == @items.length - 1 ] }
  end
end
