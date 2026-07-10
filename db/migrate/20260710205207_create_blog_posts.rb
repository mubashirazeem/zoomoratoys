class CreateBlogPosts < ActiveRecord::Migration[7.2]
  def change
    create_table :blog_posts do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :excerpt, null: false
      t.text :body, null: false
      t.string :cover_image_key, null: false
      t.datetime :published_at, null: false

      t.timestamps
    end

    add_index :blog_posts, :slug, unique: true
  end
end
