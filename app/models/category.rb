# frozen_string_literal: true

class Category < ApplicationRecord
  # Visual "kind" for a category/product. Drives which placeholder photo
  # (category-<key>.jpg) is used. Several categories intentionally share a
  # key/photo (e.g. "scooter" is used by both Scooters and Cargo Scooters) —
  # display labels come from Category#name directly, not from this key, so
  # that sharing never causes two categories to show the same label.
  PLACEHOLDER_KEYS = %w[
    bicycle scooter pool dirtbike atv rideon golf_cart trampoline playset
  ].freeze

  has_many :products, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :placeholder_key, presence: true, inclusion: { in: PLACEHOLDER_KEYS }

  before_validation :assign_slug, on: :create

  scope :ordered, -> { order(:position, :name) }

  def to_param
    slug
  end

  private

  def assign_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
