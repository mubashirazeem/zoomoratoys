# frozen_string_literal: true

# One tile in a "why shop with us" trust band. Icon + title + description,
# never color- or icon-only — see ACCESSIBILITY_GUIDELINES.md.
class Marketing::TrustBadgeComponent < ViewComponent::Base
  ICONS = %w[shipping support quality warranty].freeze

  def initialize(icon:, title:, description:)
    raise ArgumentError, "unknown trust badge icon: #{icon.inspect}" unless ICONS.include?(icon)

    @icon = icon
    @title = title
    @description = description
  end

  attr_reader :icon, :title, :description
end
