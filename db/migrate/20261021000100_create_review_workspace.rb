# frozen_string_literal: true

class CreateReviewWorkspace < ActiveRecord::Migration[8.0]
  def change
    create_table :workspaces do |t|
      t.string :name, null: false
      t.timestamps
    end
    create_table :users do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "reviewer"
      t.timestamps
    end
    add_index :users, :email, unique: true
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :sessions, :token_digest, unique: true
    create_table :documents do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :title, null: false
      t.string :filename, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :pages, null: false, default: []
      t.string :source_sha256, null: false
      t.integer :revision, null: false, default: 0
      t.datetime :approved_at
      t.timestamps
    end
    create_table :contract_fields do |t|
      t.references :document, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.text :value
      t.text :evidence
      t.integer :page
      t.string :review_state, null: false, default: "pending"
      t.text :note
      t.timestamps
    end
    add_index :contract_fields, [:document_id, :key], unique: true
    create_table :review_events do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
  end
end
