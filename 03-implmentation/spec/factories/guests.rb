FactoryBot.define do
  factory :guest do
    sequence(:xen_name) { |n| "guest-#{n}" }
  end
end
