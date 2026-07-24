# frozen_string_literal: true

class Admin::ProductVariantsController < Admin::BaseController
  before_action :set_product
  before_action :set_variant, only: [ :edit, :update, :destroy ]

  def index
    @variants = @product.product_variants.order(:id)
  end

  def new
    @variant = @product.product_variants.new
  end

  def create
    @variant = @product.product_variants.new(variant_params)

    if @variant.save
      redirect_to admin_product_variants_path(@product), notice: "Variant created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @variant.update(variant_params)
      redirect_to admin_product_variants_path(@product), notice: "Variant updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @variant.destroy
      redirect_to admin_product_variants_path(@product), notice: "Variant deleted."
    else
      redirect_to admin_product_variants_path(@product), alert: @variant.errors.full_messages.to_sentence
    end
  end

  private

  # Product#to_param returns the slug (see the same note on
  # Admin::ProductsController) — params[:product_id] is a slug, not an id.
  def set_product
    @product = Product.find_by!(slug: params[:product_id])
  end

  # ProductVariant doesn't override to_param (no slug of its own), so a
  # plain numeric find is correct here — unlike Product/Category above.
  def set_variant
    @variant = @product.product_variants.find(params[:id])
  end

  def variant_params
    permitted = params.require(:product_variant).permit(:sku, :price, :stock_quantity, :options_text)

    if permitted.key?(:options_text)
      permitted[:options] = parse_options(permitted.delete(:options_text))
    end

    permitted
  end

  # Same "Label: Value" one-per-line pattern as Admin::ProductsController's
  # specifications textarea — simpler and safer than accepting an arbitrary
  # nested params hash directly from a form.
  def parse_options(text)
    text.to_s.split("\n").filter_map do |line|
      label, value = line.split(":", 2)
      next if label.blank? || value.blank?

      [ label.strip, value.strip ]
    end.to_h
  end
end
