namespace :catalog do
  desc "One-time fix: backfill stock_quantity for products stuck at the untouched 0/in_stock combination the rafplay import left behind (see db/seeds.rb). Safe to re-run — a no-op once nothing matches."
  task backfill_stock_quantity: :environment do
    scope = Product.where(stock_quantity: 0, stock_status: "in_stock")
    total = scope.count
    puts "Found #{total} product(s) marked in stock with zero real quantity."

    scope.find_each do |product|
      quantity = 10 + (Digest::MD5.hexdigest("#{product.name}-stock").to_i(16) % 21)
      # update_columns: a pure inventory-count backfill has no business
      # tripping over unrelated pre-existing validation issues on these rows
      # (e.g. an oversized image attached before the 10MB limit existed) or
      # re-deriving stock_status via callbacks — it's already "in_stock".
      product.update_columns(stock_quantity: quantity)
    end

    puts "Backfilled #{total} product(s)."
  end

  desc "One-time fix: backfill stock_quantity for product variants stuck at 0 (rafplay's per-variant stock data was almost entirely unusable — see db/seeds.rb). Safe to re-run — a no-op once nothing matches."
  task backfill_variant_stock_quantity: :environment do
    scope = ProductVariant.where(stock_quantity: 0)
    total = scope.count
    puts "Found #{total} variant(s) with zero real quantity."

    scope.find_each do |variant|
      quantity = 10 + (Digest::MD5.hexdigest("#{variant.sku}-stock").to_i(16) % 21)
      variant.update_columns(stock_quantity: quantity)
    end

    puts "Backfilled #{total} variant(s)."
  end
end
