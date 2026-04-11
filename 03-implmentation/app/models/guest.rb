class Guest < ApplicationRecord
  validates :xen_name, presence: true, uniqueness: true,
                        format: { with: /\A[a-zA-Z0-9_\-]+\z/, message: "only letters, numbers, hyphens and underscores allowed" }
end
