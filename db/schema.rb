# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2023_09_11_162520) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "unaccent"

  create_table "batch_uploads", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "filename"
    t.string "record_type"
    t.float "progress"
    t.string "error"
    t.bigint "client_id"
    t.boolean "run_initial_report"
    t.integer "imported_record_count"
    t.index ["client_id"], name: "index_batch_uploads_on_client_id"
  end

  create_table "client_searchers", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.integer "searcher"
    t.boolean "enabled", default: true
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "skip"
    t.index ["client_id"], name: "index_client_searchers_on_client_id"
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "legal_business_name"
    t.string "physical_address"
    t.string "mailing_address"
    t.string "phone"
    t.string "fax"
    t.string "primary_contact_name"
    t.string "primary_contact_title"
    t.string "primary_contact_email"
    t.string "billing_contact_name"
    t.string "billing_contact_title"
    t.string "billing_contact_email"
    t.string "business_type"
    t.string "state_of_incorporation"
    t.string "tax_id_number"
    t.string "billing_contact_phone"
    t.integer "max_employees"
    t.bigint "parent_id"
    t.string "client_type", default: "company"
    t.string "mailing_city"
    t.string "mailing_state"
    t.string "mailing_zip"
    t.string "physical_city"
    t.string "physical_state"
    t.string "physical_zip"
    t.string "billing_city"
    t.string "billing_state"
    t.string "billing_zip"
    t.string "billing_address"
    t.boolean "billing_same_as_mailing", default: false
    t.datetime "next_report_at"
    t.bigint "primary_contact_id"
    t.text "notes"
    t.string "notes_updated_by"
    t.datetime "notes_updated_at"
    t.integer "isolved_client_id"
    t.text "isolved_client_name"
    t.integer "isolved_legal_company_id"
    t.text "isolved_legal_company_name"
    t.integer "isolved_location_id"
    t.text "isolved_location_name"
    t.string "central_management_id"
    t.float "external_sync_progress"
    t.datetime "last_external_sync_at"
    t.text "external_sync_error"
    t.text "automatic_report_info"
    t.boolean "deactivated", default: false
    t.string "ukg_id"
    t.string "isolved_endpoint"
    t.integer "monthly_report_day", default: 1
    t.index ["parent_id"], name: "index_clients_on_parent_id"
    t.index ["primary_contact_id"], name: "index_clients_on_primary_contact_id"
  end

  create_table "clients_users", id: false, force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_clients_users_on_client_id"
    t.index ["user_id"], name: "index_clients_users_on_user_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.date "dob"
    t.string "ssn"
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "middle_name"
    t.text "blocked_searchers", default: [], array: true
    t.string "isolved_id"
    t.string "central_management_id"
    t.string "la_license_number"
    t.string "tx_license_number"
    t.bigint "batch_upload_id"
    t.text "notes"
    t.datetime "notes_updated_at"
    t.bigint "notes_updated_by_id"
    t.string "ukg_id"
    t.integer "la_license_type", default: 0
    t.boolean "skip"
    t.index ["batch_upload_id"], name: "index_employees_on_batch_upload_id"
    t.index ["client_id"], name: "index_employees_on_client_id"
    t.index ["notes_updated_by_id"], name: "index_employees_on_notes_updated_by_id"
  end

  create_table "failed_reports", force: :cascade do |t|
    t.bigint "report_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "error"
    t.integer "employee_id"
    t.bigint "client_id"
    t.index ["client_id"], name: "index_failed_reports_on_client_id"
    t.index ["report_id"], name: "index_failed_reports_on_report_id"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "client_id"
    t.bigint "user_id"
    t.text "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_notes_on_client_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.string "job_id"
    t.bigint "client_id"
    t.string "filename"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "progress"
    t.string "error"
    t.string "status"
    t.json "data"
    t.string "source"
    t.integer "employee_mask", array: true
    t.integer "vendor_mask", array: true
    t.bigint "parent_report_id"
    t.integer "month"
    t.integer "year"
    t.index ["client_id"], name: "index_reports_on_client_id"
    t.index ["parent_report_id"], name: "index_reports_on_parent_report_id"
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "resource_type"
    t.integer "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["name"], name: "index_roles_on_name"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource_type_and_resource_id"
  end

  create_table "sidekiq_jobs", id: :serial, force: :cascade do |t|
    t.string "jid"
    t.string "queue"
    t.string "class_name"
    t.text "args"
    t.boolean "retry"
    t.datetime "enqueued_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string "status"
    t.string "name"
    t.text "result"
    t.index ["class_name"], name: "index_sidekiq_jobs_on_class_name"
    t.index ["enqueued_at"], name: "index_sidekiq_jobs_on_enqueued_at"
    t.index ["finished_at"], name: "index_sidekiq_jobs_on_finished_at"
    t.index ["jid"], name: "index_sidekiq_jobs_on_jid"
    t.index ["queue"], name: "index_sidekiq_jobs_on_queue"
    t.index ["retry"], name: "index_sidekiq_jobs_on_retry"
    t.index ["started_at"], name: "index_sidekiq_jobs_on_started_at"
    t.index ["status"], name: "index_sidekiq_jobs_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "title"
    t.string "phone"
    t.bigint "client_id"
    t.boolean "is_suspended"
    t.boolean "receive_notification_emails", default: true
    t.index ["client_id"], name: "index_users_on_client_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "role_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  create_table "vendors", force: :cascade do |t|
    t.string "name"
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ein"
    t.string "npi"
    t.string "first_name"
    t.string "last_name"
    t.text "blocked_searchers", default: [], array: true
    t.string "middle_name"
    t.string "la_license_number"
    t.string "tx_license_number"
    t.bigint "batch_upload_id"
    t.text "notes"
    t.datetime "notes_updated_at"
    t.bigint "notes_updated_by_id"
    t.integer "la_license_type", default: 0
    t.index ["batch_upload_id"], name: "index_vendors_on_batch_upload_id"
    t.index ["client_id"], name: "index_vendors_on_client_id"
    t.index ["notes_updated_by_id"], name: "index_vendors_on_notes_updated_by_id"
  end

  add_foreign_key "client_searchers", "clients"
  add_foreign_key "employees", "batch_uploads"
  add_foreign_key "employees", "clients"
  add_foreign_key "employees", "users", column: "notes_updated_by_id"
  add_foreign_key "failed_reports", "clients"
  add_foreign_key "failed_reports", "reports"
  add_foreign_key "notes", "clients"
  add_foreign_key "notes", "users"
  add_foreign_key "reports", "clients"
  add_foreign_key "users", "clients"
  add_foreign_key "vendors", "batch_uploads"
  add_foreign_key "vendors", "clients"
  add_foreign_key "vendors", "users", column: "notes_updated_by_id"
end
