FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { "operator" }

    trait :admin do
      role { "admin" }
    end

    trait :viewer do
      role { "viewer" }
    end
  end
end
