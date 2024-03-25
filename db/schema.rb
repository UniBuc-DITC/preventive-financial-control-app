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

ActiveRecord::Schema[7.1].define(version: 2024_03_25_084940) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.datetime "timestamp", precision: nil, null: false
    t.bigint "user_id", null: false
    t.integer "action", null: false
    t.integer "target_table", null: false
    t.text "target_object_id", null: false
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "commitments", force: :cascade do |t|
    t.integer "year", null: false
    t.integer "registration_number", null: false
    t.bigint "financing_source_id", null: false
    t.bigint "expenditure_article_id", null: false
    t.string "document_number", null: false
    t.string "validity", null: false
    t.string "procurement_type", default: "", null: false
    t.string "partner", null: false
    t.decimal "value", precision: 15, scale: 2
    t.string "noncompliance", default: "", null: false
    t.string "remarks", default: "", null: false
    t.bigint "created_by_user_id"
    t.bigint "updated_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "registration_date", default: -> { "CURRENT_DATE" }, null: false
    t.string "project_details", default: "", null: false
    t.index ["created_by_user_id"], name: "index_commitments_on_created_by_user_id"
    t.index ["expenditure_article_id"], name: "index_commitments_on_expenditure_article_id"
    t.index ["financing_source_id"], name: "index_commitments_on_financing_source_id"
    t.index ["updated_by_user_id"], name: "index_commitments_on_updated_by_user_id"
    t.index ["year", "registration_number"], name: "index_commitments_on_year_and_registration_number", unique: true
  end

  create_table "expenditure_articles", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "expenditure_category_code", default: "", null: false
    t.string "commitment_category_code", default: "", null: false
    t.index ["code"], name: "index_expenditure_articles_on_code", unique: true
  end

  create_table "expenditures", force: :cascade do |t|
    t.integer "year", null: false
    t.integer "registration_number", null: false
    t.date "registration_date", default: -> { "CURRENT_DATE" }, null: false
    t.bigint "financing_source_id", null: false
    t.bigint "project_category_id"
    t.bigint "expenditure_article_id", null: false
    t.string "details", default: "", null: false
    t.string "procurement_type", default: "", null: false
    t.string "ordinance_number"
    t.date "ordinance_date"
    t.decimal "value", precision: 15, scale: 2
    t.bigint "payment_method_id", null: false
    t.string "beneficiary", null: false
    t.string "invoice", default: "", null: false
    t.string "noncompliance", default: "", null: false
    t.string "remarks", default: "", null: false
    t.bigint "created_by_user_id"
    t.bigint "updated_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "project_details", default: "", null: false
    t.index ["created_by_user_id"], name: "index_expenditures_on_created_by_user_id"
    t.index ["expenditure_article_id"], name: "index_expenditures_on_expenditure_article_id"
    t.index ["financing_source_id"], name: "index_expenditures_on_financing_source_id"
    t.index ["payment_method_id"], name: "index_expenditures_on_payment_method_id"
    t.index ["project_category_id"], name: "index_expenditures_on_project_category_id"
    t.index ["updated_by_user_id"], name: "index_expenditures_on_updated_by_user_id"
    t.index ["year", "registration_number"], name: "index_expenditures_on_year_and_registration_number", unique: true
  end

  create_table "financing_sources", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_financing_sources_on_name", unique: true
  end

  create_table "payment_methods", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_payment_methods_on_name", unique: true
  end

  create_table "project_categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_project_categories_on_name", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.json "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "entra_user_id", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entra_user_id"], name: "index_users_on_entra_user_id", unique: true
  end

  add_foreign_key "audit_events", "users"
  add_foreign_key "commitments", "expenditure_articles"
  add_foreign_key "commitments", "financing_sources"
  add_foreign_key "commitments", "users", column: "created_by_user_id"
  add_foreign_key "commitments", "users", column: "updated_by_user_id"
  add_foreign_key "expenditures", "expenditure_articles"
  add_foreign_key "expenditures", "financing_sources"
  add_foreign_key "expenditures", "payment_methods"
  add_foreign_key "expenditures", "project_categories"
  add_foreign_key "expenditures", "users", column: "created_by_user_id"
  add_foreign_key "expenditures", "users", column: "updated_by_user_id"
end
