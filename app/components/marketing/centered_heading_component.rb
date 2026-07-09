# frozen_string_literal: true

# Centered uppercase section heading flanked by horizontal rules, used above
# full-width sections like "Best Selling Products" and "Explore Categories".
class Marketing::CenteredHeadingComponent < ViewComponent::Base
  def initialize(title:)
    @title = title
  end

  attr_reader :title
end
