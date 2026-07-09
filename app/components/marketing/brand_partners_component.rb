# frozen_string_literal: true

# "Official Brand Partners" logo strip. Uses invented, original placeholder
# brand names and simple geometric monogram marks — never real third-party
# automaker/manufacturer logos, which are trademarks.
class Marketing::BrandPartnersComponent < ViewComponent::Base
  Partner = Struct.new(:name, :monogram, keyword_init: true)

  PARTNERS = [
    Partner.new(name: "Velocité", monogram: "V"),
    Partner.new(name: "TerraMax", monogram: "T"),
    Partner.new(name: "Nimbus", monogram: "N"),
    Partner.new(name: "Summit", monogram: "S"),
    Partner.new(name: "Halcyon", monogram: "H"),
    Partner.new(name: "Meridian", monogram: "M")
  ].freeze

  def partners
    PARTNERS
  end
end
