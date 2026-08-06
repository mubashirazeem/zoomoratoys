# frozen_string_literal: true

# Content-type/size/count validation for has_one_attached/has_many_attached
# image fields. Without this, any admin could upload an arbitrarily large
# file of any type — which then flows into ImageMagick variant processing
# on nearly every customer-facing page (see Product#display_photo and
# Catalog::ProductGalleryComponent).
module ImageAttachmentValidatable
  extend ActiveSupport::Concern

  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_BYTES = 10.megabytes

  class_methods do
    def validates_image_attachment(attachment_name, max_count: nil)
      validate do
        attached = public_send(attachment_name)
        next unless attached.attached?

        blobs = attached.respond_to?(:each) ? attached.map(&:blob).compact : [ attached.blob ].compact

        if max_count && blobs.size > max_count
          errors.add(attachment_name, "can have at most #{max_count} images")
        end

        blobs.each do |blob|
          unless ALLOWED_IMAGE_TYPES.include?(blob.content_type)
            errors.add(attachment_name, "must be a JPEG, PNG, or WebP image")
          end
          if blob.byte_size > MAX_IMAGE_BYTES
            errors.add(attachment_name, "must be smaller than #{MAX_IMAGE_BYTES / 1.megabyte}MB")
          end
        end
      end
    end
  end
end
