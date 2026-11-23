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

ActiveRecord::Schema[8.1].define(version: 2026_11_22_042006) do
  create_table "rsvps", force: :cascade do |t|
    t.integer "user_id"
    t.string "email"
    t.string "source", null: false
    t.string "building"
    t.string "heard_from"
    t.string "ref"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "linked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_rsvps_on_email", unique: true
    t.index ["ref"], name: "index_rsvps_on_ref"
    t.index ["user_id"], name: "index_rsvps_on_user_id", unique: true
    t.check_constraint "user_id IS NOT NULL OR email IS NOT NULL", name: "rsvps_user_or_email"
  end

  create_table "users", force: :cascade do |t|
    t.string "hca_id"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "slack_id"
    t.string "verification_status"
    t.boolean "ysws_eligible"
    t.datetime "last_signed_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email"
    t.index ["hca_id"], name: "index_users_on_hca_id", unique: true
    t.index ["slack_id"], name: "index_users_on_slack_id", unique: true
  end

  add_foreign_key "rsvps", "users"
end
