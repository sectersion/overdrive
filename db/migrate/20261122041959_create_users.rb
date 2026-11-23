class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Hack Club Auth public id ("ident!xxxx"). Nil for users we only know from a Slack click.
      t.string :hca_id
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :slack_id
      # needs_submission | pending | verified | ineligible (HCA), or the external-check result for Slack-only users
      t.string :verification_status
      t.boolean :ysws_eligible
      t.datetime :last_signed_in_at

      t.timestamps
    end
    add_index :users, :hca_id, unique: true
    add_index :users, :slack_id, unique: true
    add_index :users, :email
  end
end
