# frozen_string_literal: true

# Backs Order.generate_order_number. Always exactly one row in real
# environments (seeded by the CreateOrderNumberCounters migration); see
# Order.generate_order_number for the lazy self-heal used when a database
# was rebuilt from db/schema.rb instead of migrated (schema.rb captures
# table structure only, not this table's seed row).
class OrderNumberCounter < ApplicationRecord
end
