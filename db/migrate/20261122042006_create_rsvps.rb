class CreateRsvps < ActiveRecord::Migration[8.1]
  def change
    create_table :rsvps do |t|
      # An RSVP belongs to a user (HCA or Slack) or is a bare email, until linked.
      t.references :user, null: true, foreign_key: true, index: { unique: true }
      t.string :email, index: { unique: true }
      t.string :source, null: false # email | hca | slack
      t.string :building
      t.string :heard_from
      t.string :ref
      t.string :ip_address
      t.string :user_agent
      t.datetime :linked_at # when an email RSVP got attached to a Hack Club account

      t.timestamps
    end
    add_index :rsvps, :ref
    add_check_constraint :rsvps, "user_id IS NOT NULL OR email IS NOT NULL", name: "rsvps_user_or_email"
  end
end
