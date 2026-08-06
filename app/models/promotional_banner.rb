# frozen_string_literal: true

# Admin-managed, photo-backed homepage banners (client feedback, 2026-08-02:
# "all of these banners... should be like [the hero]... I want to be able to
# edit them... changing these pictures, changing everything on all of these
# four banners"). Rendered by Marketing::PromoBannerCarouselComponent as a
# single-slide-at-a-time, auto-advancing carousel, same as the hero.
class PromotionalBanner < ApplicationRecord
  include ImageAttachmentValidatable

  has_paper_trail

  # The uploaded photo sits behind a fixed dark gradient overlay (see the
  # component template) so white title/description text stays readable
  # regardless of what image an admin uploads — no separate "tone" field to
  # get wrong.
  has_one_attached :image

  validates :title, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates_image_attachment :image
  # A CTA only makes sense as a pair — a label with nowhere to go, or a URL
  # with no visible button text, are both broken states worth catching at
  # save time rather than rendering a dead/blank button on the live site.
  validate :cta_label_and_url_must_be_both_or_neither
  # Blocks a javascript:/data: URI from being stored as a CTA link — cta_url
  # renders through Ui::ButtonComponent's tag.a, which doesn't filter the
  # href scheme itself. Relative paths (no scheme) are allowed.
  validate :cta_url_must_use_a_safe_scheme

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

  def cta_url_must_use_a_safe_scheme
    return if cta_url.blank?

    uri = URI.parse(cta_url)
    return if uri.scheme.nil? || %w[http https].include?(uri.scheme)

    errors.add(:cta_url, "must be a relative path or an http(s) link")
  rescue URI::InvalidURIError
    errors.add(:cta_url, "isn't a valid link")
  end
end
