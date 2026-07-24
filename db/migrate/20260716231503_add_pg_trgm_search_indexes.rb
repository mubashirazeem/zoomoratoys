# frozen_string_literal: true

# Product/Order/User `.search` scopes use `ILIKE '%...%'` (see each model),
# which a plain btree index can't accelerate — the leading wildcard means
# Postgres can't use a sorted index range scan, only a full table scan.
# Fine at today's row counts; a real problem once these tables hold
# millions of rows. pg_trgm's GIN trigram indexes are the standard
# Postgres answer, and need zero query-code changes — the existing ILIKE
# scopes start using these indexes automatically.
class AddPgTrgmSearchIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  TRIGRAM_INDEXES = {
    products: %w[name description sku],
    orders: %w[order_number],
    users: %w[first_name last_name email]
  }.freeze

  def up
    enable_extension "pg_trgm"

    TRIGRAM_INDEXES.each do |table, columns|
      columns.each do |column|
        # Each CREATE INDEX CONCURRENTLY must be its own statement/connection
        # call — Postgres refuses to run it inside any transaction block,
        # including one implied by batching multiple statements together.
        execute "CREATE INDEX CONCURRENTLY IF NOT EXISTS index_#{table}_on_#{column}_trgm ON #{table} USING gin (#{column} gin_trgm_ops)"
      end
    end
  end

  def down
    TRIGRAM_INDEXES.each do |table, columns|
      columns.each do |column|
        execute "DROP INDEX CONCURRENTLY IF EXISTS index_#{table}_on_#{column}_trgm"
      end
    end

    disable_extension "pg_trgm"
  end
end
