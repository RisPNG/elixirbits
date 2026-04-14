defmodule Elixirbits.AccessControl do
  use Ash.Domain,
    otp_app: :elixirbits,
    extensions: [AshPaperTrail.Domain]

  paper_trail do
    include_versions? true
  end

  resources do
    resource Elixirbits.AccessControl.Sitenav
    resource Elixirbits.AccessControl.Role
    resource Elixirbits.AccessControl.RolePerm
  end
end
