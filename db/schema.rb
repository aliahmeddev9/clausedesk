# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_26_000100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "contract_fields", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.text "value"
    t.text "evidence"
    t.integer "page"
    t.string "review_state", default: "pending", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uncertainty"
    t.index ["document_id", "key"], name: "index_contract_fields_on_document_id_and_key", unique: true
    t.index ["document_id"], name: "index_contract_fields_on_document_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "title", null: false
    t.string "filename", null: false
    t.string "status", default: "draft", null: false
    t.jsonb "pages", default: [], null: false
    t.string "source_sha256", null: false
    t.integer "revision", default: 0, null: false
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "extraction_mode", default: "local_rules", null: false
    t.jsonb "extraction_metadata", default: {}, null: false
    t.index ["workspace_id"], name: "index_documents_on_workspace_id"
  end

  create_table "extraction_runs", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "running", null: false
    t.string "model", null: false
    t.integer "revision", null: false
    t.jsonb "usage", default: {}, null: false
    t.string "error_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_extraction_runs_on_document_id"
    t.index ["user_id"], name: "index_extraction_runs_on_user_id"
  end

  create_table "review_events", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_review_events_on_document_id"
    t.index ["user_id"], name: "index_review_events_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "workspace_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "reviewer", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["workspace_id"], name: "index_users_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "demo_expires_at"
    t.index ["demo_expires_at"], name: "index_workspaces_on_demo_expires_at"
  end

  add_foreign_key "contract_fields", "documents"
  add_foreign_key "documents", "workspaces"
  add_foreign_key "extraction_runs", "documents"
  add_foreign_key "extraction_runs", "users"
  add_foreign_key "review_events", "documents"
  add_foreign_key "review_events", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "workspaces"
end
