# frozen_string_literal: true

# Dashboard metric tile — real counts only (see Admin::DashboardController),
# never a fabricated trend/percentage. icon is one of ICONS' keys.
class Admin::StatCardComponent < ViewComponent::Base
  ICONS = {
    box: '<path d="M20 7 12 3 4 7v10l8 4 8-4V7Z"/><path d="M4 7l8 4 8-4M12 11v10"/>'.html_safe,
    grid: '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/>'.html_safe,
    people: '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>'.html_safe,
    bag: '<path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z"/><path d="M3 6h18M16 10a4 4 0 0 1-8 0"/>'.html_safe,
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/>'.html_safe,
    tag: '<path d="M20.59 13.41 13.41 20.6a2 2 0 0 1-2.83 0L2 12.99V2h10.99l8.6 8.58a2 2 0 0 1 0 2.83Z"/><circle cx="7.5" cy="7.5" r="1.5"/>'.html_safe
  }.freeze

  def initialize(value:, label:, icon:, href: nil, accent: :default)
    @value = value
    @label = label
    @icon = icon
    @href = href
    @accent = accent
  end

  attr_reader :value, :label, :href, :accent

  def icon_markup
    ICONS.fetch(@icon)
  end

  def accent_classes
    accent == :alert ? "bg-red-600/10 text-red-600" : "bg-ink-950/5 text-ink-950"
  end

  def value_classes
    accent == :alert ? "text-red-600" : "text-ink-950"
  end
end
