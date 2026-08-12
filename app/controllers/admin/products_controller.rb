# frozen_string_literal: true

class Admin::ProductsController < Admin::BaseController
  PER_PAGE = 24

  before_action :set_product, only: [ :edit, :update, :destroy ]

  def index
    @products = Product.includes(:category, :product_variants).order(created_at: :desc)
    @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?
    @products = @products.search(params[:q]) if params[:q].present?
    @products = @products.page(params[:page]).per(PER_PAGE)
    @categories = Category.ordered
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to admin_products_path, notice: "Product created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to admin_products_path, notice: "Product updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @product.destroy
      redirect_to admin_products_path, notice: "Product deleted."
    else
      redirect_to admin_products_path, alert: @product.errors.full_messages.to_sentence
    end
  end

  private

  # Product#to_param returns the slug (for customer-facing SEO URLs), so
  # every admin_product_path(product)/form_with helper call generates a
  # slug-based URL too — look up the same way, not by numeric id.
  def set_product
    @product = Product.find_by!(slug: params[:id])
  end

  def product_params
    permitted = params.require(:product).permit(
      :name, :description, :price, :compare_at_price, :sku, :stock_status,
      :stock_quantity, :featured, :best_seller, :position, :placeholder_key,
      :category_id, :specifications_text, :safety_notes, :care_notes,
      :delivery_note, :warranty_note, images: []
    )

    if permitted.key?(:specifications_text)
      permitted[:specifications] = parse_specifications(permitted.delete(:specifications_text))
    end

    permitted
  end

  # Admin types one spec per line as "Label: Value" — parsed into the
  # specifications jsonb hash. Simpler and safer to reason about than
  # accepting an arbitrary nested params hash directly from a form.
  def parse_specifications(text)
    text.to_s.split("\n").filter_map do |line|
      label, value = line.split(":", 2)
      next if label.blank? || value.blank?

      [ label.strip, value.strip ]
    end.to_h
  end
end
