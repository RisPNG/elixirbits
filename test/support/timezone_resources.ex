defmodule Poppybit.CoreUtils.ResourceTest.SequenceRow do
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults create: [:sequence]
  end

  attributes do
    attribute :sequence, :integer, public?: true
    attribute :at, :utc_datetime, public?: true
    attribute :precise_at, :utc_datetime_usec, public?: true
    attribute :local_at, :naive_datetime, public?: true
  end
end

defmodule Poppybit.CoreUtils.Resource.SearchDatetimeTest.Record do
  use Ash.Resource,
    domain: Poppybit.CoreUtils.Resource.SearchDatetimeTest.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  actions do
    defaults [:read, create: [:name, :at, :native_at]]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :at, :utc_datetime_usec
    attribute :native_at, :datetime, constraints: [precision: :microsecond]
  end
end

defmodule Poppybit.CoreUtils.Resource.SearchDatetimeTest.Domain do
  use Ash.Domain, otp_app: :poppybit, validate_config_inclusion?: false

  resources do
    resource Poppybit.CoreUtils.Resource.SearchDatetimeTest.Record
  end
end

defmodule Poppybit.CoreUtils.ResourceTest.PreciseInstant do
  use Ash.Type.NewType, subtype_of: :datetime, constraints: [precision: :microsecond]
end

defmodule Poppybit.CoreUtils.ResourceTest.FormRow do
  use Ash.Resource,
    domain: Poppybit.CoreUtils.ResourceTest.FormDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:at, :precise_at, :native_at, :wrapped_at, :due_date, :opens_at, :local_at, :slots]
      argument :remind_at, :datetime, constraints: [precision: :microsecond]
      change set_attribute(:reminder_at, arg(:remind_at))
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :at, :utc_datetime
    attribute :precise_at, :utc_datetime_usec
    attribute :native_at, :datetime, constraints: [precision: :microsecond]
    attribute :wrapped_at, Poppybit.CoreUtils.ResourceTest.PreciseInstant
    attribute :reminder_at, :utc_datetime_usec
    attribute :due_date, :date
    attribute :opens_at, :time
    attribute :local_at, :naive_datetime
    attribute :slots, {:array, :datetime}, constraints: [items: [precision: :microsecond]]
    timestamps()
  end
end

defmodule Poppybit.CoreUtils.ResourceTest.FormParent do
  use Ash.Resource,
    domain: Poppybit.CoreUtils.ResourceTest.FormDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept []
      argument :children, {:array, :map}
      change manage_relationship(:children, type: :direct_control)
    end
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    has_many :children, Poppybit.CoreUtils.ResourceTest.FormChild
  end
end

defmodule Poppybit.CoreUtils.ResourceTest.FormChild do
  use Ash.Resource,
    domain: Poppybit.CoreUtils.ResourceTest.FormDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:at, :form_parent_id]
    end

    update :update do
      primary? true
      accept [:at]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :at, :datetime, constraints: [precision: :microsecond]
    timestamps()
  end

  relationships do
    belongs_to :form_parent, Poppybit.CoreUtils.ResourceTest.FormParent do
      attribute_writable? true
    end
  end
end

defmodule Poppybit.CoreUtils.ResourceTest.FormDomain do
  use Ash.Domain, otp_app: :poppybit, validate_config_inclusion?: false

  resources do
    resource Poppybit.CoreUtils.ResourceTest.FormRow
    resource Poppybit.CoreUtils.ResourceTest.FormParent
    resource Poppybit.CoreUtils.ResourceTest.FormChild
  end
end
