class CreateOrderNumberCounters < ActiveRecord::Migration[7.2]
  # A single-row table rather than a Postgres SEQUENCE: sequences aren't
  # captured by db/schema.rb (only table/column structure is), so a fresh
  # test/CI database rebuilt via `db:schema:load` would silently be missing
  # it. A real table is fully portable, and Order.generate_order_number
  # locks this row the same way create_from_cart! already locks Product/
  # ProductVariant rows for concurrency safety.
  def up
    create_table :order_number_counters do |t|
      t.integer :next_value, null: false
      t.timestamps
    end

    order_ids = execute("SELECT id FROM orders ORDER BY placed_at ASC").map { |row| row["id"] }
    order_ids.each_with_index do |id, index|
      execute "UPDATE orders SET order_number = 'ZMR-#{1000 + index}' WHERE id = #{id}"
    end

    execute "INSERT INTO order_number_counters (next_value, created_at, updated_at) VALUES (#{1000 + order_ids.size}, now(), now())"
  end

  def down
    drop_table :order_number_counters
  end
end
