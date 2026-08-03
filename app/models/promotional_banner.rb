# frozen_string_literal: true

# Admin-managed, photo-backed homepage banners (client feedback, 2026-08-02:
# "all of these banners... should be like [the hero]... I want to be able to
# edit them... changing these pictures, changing everything on all of these
# four banners"). Rendered by Marketing::PromoBannerCarouselComponent as a
# single-slide-at-a-time, auto-advancing carousel, same as the hero.
class PromotionalBanner < ApplicationRecord
  has_paper_trail

  # The uploaded photo sits behind a fixed dark gradient overlay (see the
  # component template) so white title/description text stays readable
  # regardless of what image an admin uploads — no separate "tone" field to
  # get wrong.
  has_one_attached :image

  validates :title, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # A CTA only makes sense as a pair — a label with nowhere to go, or a URL
  # with no visible button text, are both broken states worth catching at
  # save time rather than rendering a dead/blank button on the live site.
  validate :cta_label_and_url_must_be_both_or_neither

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :created_at) }

  def cta?
    cta_label.present? && cta_url.present?
  end

  private

  def cta_label_and_url_must_be_both_or_neither
    return if cta_label.present? == cta_url.present?

    errors.add(:base, "Button text and button link must both be filled in, or both left blank")
  end
end
