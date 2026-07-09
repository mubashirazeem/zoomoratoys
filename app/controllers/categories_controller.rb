class CategoriesController < ApplicationController
  def index
    @categories = @nav_categories
  end
end
