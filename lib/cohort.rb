# encoding: UTF-8
class Cohort < ActiveRecord::Base
  establish_connection "long_connection_#{Rails.env}"

  class << self
    def activities_users(period = "month", intervals = (Date.today.month - 1))
      users      = []
      dayone      = []
      activities = []
      # user data
      (intervals).times.each do |interval|
        users[interval] = Rails.cache.fetch("cohort_users_#{interval}", expires_in: 1.day) do
          User.where("created_at BETWEEN '2013-#{interval + 1}-01 00:00:00' AND '2013-#{interval + 2}-01 00:00:00' AND email NOT LIKE '%shopcliq%'").pluck(:id)
        end
      end
      # dayone data
      users.each_with_index do |users_id, interval|
        dayone[interval] = Rails.cache.fetch("cohort_users_dayone_#{interval}", expires_in: 1.day) do
          key_activities_dayone_value(users_id, interval)
        end
      end
      # period data
      users.each_with_index do |users_id, interval|
        activities[interval] = []
        (intervals).times.each do |interval_for_data|
          activities[interval] << []
          activities[interval][interval_for_data] = Rails.cache.fetch("cohort_users_activities_#{interval}_#{interval_for_data}", expires_in: 1.day) do
            key_activities_value(users_id, interval_for_data)
          end
        end
      end
      result = {
        users:      users,
        dayone:     dayone,
        activities: activities
      }
      result
    end

    def key_activities_dayone_value(cohort, interval_for_data)
      just_dayone_condition = "activities.created_at < (users.created_at + interval '1' day)"
      activities            = Activity.unscoped.joins(:user).select("distinct user_id").where("user_id IN (?)", cohort).where(just_dayone_condition).count
    end

    def key_activities_value(cohort, interval_for_data)
      period_condition         = "activities.created_at BETWEEN '2013-#{interval_for_data + 1}-01 00:00:00' AND '2013-#{interval_for_data + 2}-01 00:00:00'"
      exclude_dayone_condition = "activities.created_at > (users.created_at + interval '1' day)"
      activities               = Activity.unscoped.joins(:user).select("distinct user_id").where("user_id IN (?)", cohort).where(period_condition).where(exclude_dayone_condition).count
    end
  end
end
