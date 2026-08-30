# frozen_string_literal: true

# A collapsible sidebar filter group (Categories, Colour, Availability,
# Price...). Built on native <details> so it's keyboard-accessible with no JS.
class Catalog::FilterSectionComponent < ViewComponent::Base
  renders_one :body

  def initialize(title:, open: false)
    @title = title
    @open = open
  end

  attr_reader :title, :open
end
