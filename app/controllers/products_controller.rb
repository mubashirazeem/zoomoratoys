class ProductsController < ApplicationController
  def index
    @categories = @nav_categories
    @selected_category = @categories.find { |category| category.slug == params[:category] }

    @products = Product.includes(:category).ordered
    @products = @products.where(category: @selected_category) if @selected_category
  end

  def show
    @product = Product.includes(:category).find_by!(slug: params[:slug])
    @related_products = Product.where(category: @product.category)
                                .where.not(id: @product.id)
                                .ordered
                                .limit(3)
    @recently_viewed = Product.includes(:category)
                               .where.not(id: @product.id)
                               .newest_first
                               .limit(3)
  end
end
