# based on Redmine.Journal and Redmine.JournalDetails
class Journal < ActiveRecord::Base
  include Approvable::Model

  belongs_to :journalized, polymorphic: true
  belongs_to :user
  has_many :details, class_name: 'Journal::Detail', dependent: :delete_all

  def save(*args)
    # Do not save an empty journal
    details.empty? ? false : super
  end

  class Detail < ActiveRecord::Base
    belongs_to :journal
    before_save :normalize_values

    private

    def normalize_values
      self.value = normalize(value)
      self.old_value = normalize(old_value)
    end

    def normalize(v)
      case v
        when true
          '1'
        when false
          '0'
        when Date
          v.strftime('%Y-%m-%d')
        else
          v
      end
    end
  end
end
