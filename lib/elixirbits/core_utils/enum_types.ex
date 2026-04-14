defmodule Elixirbits.CoreUtils.EnumTypes do
  @moduledoc false
end

defmodule Elixirbits.CoreUtils.EnumTypes.AddressLabel do
  use Ash.Type.Enum, values: [:HOME, :OTHER]
end

defmodule Elixirbits.CoreUtils.EnumTypes.SitenavState do
  use Ash.Type.Enum, values: [:ENABLED, :DISABLED]
end

defmodule Elixirbits.CoreUtils.EnumTypes.UserSex do
  use Ash.Type.Enum, values: [:MALE, :FEMALE]
end
