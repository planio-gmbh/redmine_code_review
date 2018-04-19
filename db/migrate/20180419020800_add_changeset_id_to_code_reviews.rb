class AddChangesetIdToCodeReviews < ActiveRecord::Migration
  def change
    add_reference :code_reviews, :changeset
  end
end
